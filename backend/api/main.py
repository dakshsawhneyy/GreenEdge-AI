
import logging
import os
import time
import uuid

import vertexai
from fastapi import FastAPI, HTTPException, Query, Request, Response
from backend.api.metrics import (
    REQUEST_COUNT,
    REQUEST_LATENCY,
    metrics_response
)
from fastapi.middleware.cors import CORSMiddleware
from google.auth import default
from google.auth.transport.requests import Request
from google.cloud import bigquery
from pydantic import BaseModel, Field
from vertexai.language_models import (
    TextEmbeddingInput,
    TextEmbeddingModel,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

logger = logging.getLogger("greenedge-api")

# --------------------------------------------------
# Configuration
# --------------------------------------------------

PROJECT_ID = os.environ["GCP_PROJECT_ID"]
REGION = os.getenv("GCP_REGION", "us-central1")

DATASET = os.getenv("BQ_DATASET", "greenedge_dev")
TELEMETRY_TABLE = os.getenv(
    "TELEMETRY_TABLE", "sensor_telemetry"
)
KNOWLEDGE_TABLE = os.getenv(
    "KNOWLEDGE_TABLE", "knowledge_chunks"
)

GEMINI_MODEL = os.getenv(
    "GEMINI_MODEL", "gemini-1.5-flash-002"
)

# --------------------------------------------------
# Initialize clients
# --------------------------------------------------

print(f"DEBUG: PROJECT_ID = {PROJECT_ID}")
print(f"DEBUG: REGION = {REGION}")
print(f"DEBUG: GEMINI_MODEL = {GEMINI_MODEL}")

vertexai.init(
    project=PROJECT_ID,
    location=REGION
)

embedding_model = TextEmbeddingModel.from_pretrained(
    "text-embedding-005"
)

# Get credentials for API calls
credentials, _ = default()
credentials.refresh(Request())

bq_client = bigquery.Client(
    project=PROJECT_ID
)

app = FastAPI(
    title="GreenEdge AI",
    description="Sustainability Operations Copilot",
    version="1.0.0"
)

@app.middleware("http")
async def request_logging(request: Request, call_next):
    request_id = str(uuid.uuid4())
    start_time = time.perf_counter()

    try:
        response = await call_next(request)

        duration_ms = round(
            (time.perf_counter() - start_time) * 1000,
            2,
        )

        response.headers["X-Request-ID"] = request_id

        logger.info(
            "request_id=%s method=%s path=%s status=%s duration_ms=%s",
            request_id,
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )

        return response

    except Exception:
        logger.exception(
            "request_id=%s method=%s path=%s unhandled_error",
            request_id,
            request.method,
            request.url.path,
        )
        raise

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


# Prometheus Middleware
from backend.api.metrics import (
    REQUEST_COUNT,
    REQUEST_LATENCY,
    metrics_response
)

@app.middleware("http")
async def prometheus_metrics(request, call_next):
    start = time.perf_counter()

    response = await call_next(request)

    duration = time.perf_counter() - start

    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()

    REQUEST_LATENCY.observe(duration)

    return response


@app.get("/metrics")
def prometheus_endpoint():
    content, content_type = metrics_response()

    return Response(
        content=content,
        media_type=content_type
    )


# --------------------------------------------------
# Request model
# --------------------------------------------------

class AskRequest(BaseModel):
    question: str = Field(min_length=5, max_length=1000)
    site_id: str = Field(min_length=1, max_length=100)


# --------------------------------------------------
# 1. Generate query embedding
# --------------------------------------------------

def embed_question(question: str):
    embedding_input = TextEmbeddingInput(
        question,
        task_type="RETRIEVAL_QUERY"
    )

    result = embedding_model.get_embeddings(
        [embedding_input]
    )

    return result[0].values


# --------------------------------------------------
# 2. Retrieve relevant knowledge
# --------------------------------------------------

def retrieve_knowledge(question: str):
    embedding = embed_question(question)

    table_id = (
        f"{PROJECT_ID}.{DATASET}.{KNOWLEDGE_TABLE}"
    )

    sql = f"""
    SELECT
        base.chunk_id,
        base.source,
        base.content,
        distance
    FROM VECTOR_SEARCH(
        TABLE `{table_id}`,
        'embedding',
        (SELECT @query_embedding AS embedding),
        top_k => 5,
        distance_type => 'COSINE'
    )
    ORDER BY distance ASC
    """

    config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ArrayQueryParameter(
                "query_embedding",
                "FLOAT64",
                embedding
            )
        ]
    )

    rows = bq_client.query(
        sql,
        job_config=config
    ).result()

    return [
        {
            "chunk_id": row.chunk_id,
            "source": row.source,
            "content": row.content,
            "distance": row.distance
        }
        for row in rows
    ]


# --------------------------------------------------
# 3. Retrieve structured telemetry
# --------------------------------------------------

def retrieve_telemetry(site_id: str):
    table_id = (
        f"{PROJECT_ID}.{DATASET}.{TELEMETRY_TABLE}"
    )

    sql = f"""
    SELECT
        COUNT(*) AS reading_count,
        ROUND(AVG(power_kw), 3) AS avg_power_kw,
        ROUND(MAX(power_kw), 3) AS max_power_kw,
        ROUND(AVG(occupancy), 2) AS avg_occupancy,

        COUNTIF(occupancy = 0) AS unoccupied_readings,

        ROUND(
            AVG(IF(occupancy = 0, power_kw, NULL)),
            3
        ) AS avg_power_when_unoccupied,

        MAX(timestamp) AS latest_reading

    FROM `{table_id}`

    WHERE site_id = @site_id
      AND timestamp >= TIMESTAMP_SUB(
          CURRENT_TIMESTAMP(),
          INTERVAL 24 HOUR
      )
    """

    config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter(
                "site_id",
                "STRING",
                site_id
            )
        ]
    )

    row = next(
        iter(
            bq_client.query(
                sql,
                job_config=config
            ).result()
        )
    )

    return {
        "period": "last 24 hours",
        "site_id": site_id,
        "reading_count": row.reading_count,
        "average_power_kw": row.avg_power_kw,
        "maximum_power_kw": row.max_power_kw,
        "average_occupancy": row.avg_occupancy,
        "unoccupied_readings": row.unoccupied_readings,
        "average_power_when_unoccupied_kw":
            row.avg_power_when_unoccupied,
        "latest_reading": (
            row.latest_reading.isoformat()
            if row.latest_reading else None
        )
    }


# --------------------------------------------------
# 4. Build grounded prompt and generate response
# --------------------------------------------------

def generate_answer(question, telemetry, knowledge):

    knowledge_context = "\n\n".join(
        [
            (
                f"Source: {item['source']}\n"
                f"Content: {item['content']}"
            )
            for item in knowledge
        ]
    )

    prompt = f"""
You are GreenEdge AI, a sustainability operations assistant.

Answer the user's question using ONLY the evidence
provided below.

USER QUESTION:
{question}

TELEMETRY EVIDENCE:
{telemetry}

RETRIEVED KNOWLEDGE:
{knowledge_context}

INSTRUCTIONS:

1. Explain what the telemetry actually demonstrates.
2. Use retrieved knowledge to explain possible causes
   and recommend investigation steps.
3. Never present a possible cause as a confirmed fact.
4. Cite knowledge sources using their exact filenames.
5. Do not invent energy readings, emissions factors,
   or potential energy savings.
6. If telemetry is missing, explicitly state that.
7. If retrieved documents do not support an answer,
   acknowledge the lack of supporting knowledge.
8. Make practical, advisory recommendations only.
9. Distinguish observations from hypotheses.

Return a clear response with these sections:

- Observations
- Possible explanations
- Recommended investigations
- Evidence and limitations
"""

    # TEMPORARY: Mock response until Gemini access is fixed
    # TODO: Enable Vertex AI or Google AI API properly
    
    mock_response = f"""
## Observations

Based on the telemetry data for {telemetry.get('site_id', 'the building')}:
- Total readings in the last 24 hours: {telemetry.get('reading_count', 0)}
- Average power consumption: {telemetry.get('average_power_kw', 0)} kW
- Power during unoccupied periods: {telemetry.get('average_power_when_unoccupied_kw', 0)} kW
- Unoccupied readings: {telemetry.get('unoccupied_readings', 0)} out of {telemetry.get('reading_count', 0)}

The data shows energy consumption continues even when the building is unoccupied.

## Possible Explanations

According to energy management best practices:

1. **HVAC Systems Running Continuously**: Many buildings leave heating/cooling systems running 24/7 rather than implementing scheduled setbacks
2. **Lighting Systems Not Automated**: Lights may be left on or lack occupancy sensors
3. **Plug Loads and Equipment**: Computers, printers, vending machines, and other equipment drawing phantom power
4. **Base Building Systems**: Elevators, security systems, emergency lighting, and data centers that must run continuously

## Recommended Investigations

1. Review HVAC schedules and implement temperature setbacks during unoccupied hours
2. Install occupancy sensors for lighting in offices, conference rooms, and restrooms
3. Audit plug loads and implement smart power strips or shutdown schedules
4. Identify which systems truly need 24/7 operation vs. those that can be scheduled

## Evidence and Limitations

This analysis is based on:
- 24-hour telemetry data from {telemetry.get('site_id', 'building-01')}
- General energy management principles from knowledge base
- Limited data on specific equipment and schedules

For a comprehensive assessment, we would need:
- Detailed equipment inventory and schedules
- Sub-metered data by system (HVAC, lighting, plug loads)
- Building automation system logs
- Longer-term historical data to identify patterns
"""
    return mock_response


# --------------------------------------------------
# 5. API endpoint
# --------------------------------------------------

@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/ask")
def ask(request: AskRequest):

    try:
        knowledge = retrieve_knowledge(
            request.question
        )

        telemetry = retrieve_telemetry(
            request.site_id
        )

        answer = generate_answer(
            request.question,
            telemetry,
            knowledge
        )

        return {
            "question": request.question,
            "site_id": request.site_id,
            "answer": answer,
            "telemetry_evidence": telemetry,
            "knowledge_sources": [
                {
                    "source": item["source"],
                    "chunk_id": item["chunk_id"],
                    "distance": item["distance"]
                }
                for item in knowledge
            ],
            "insufficient_evidence": (
                telemetry["reading_count"] == 0
                or len(knowledge) == 0
            )
        }

    except Exception as e:
        # Log the detailed exception
        import traceback
        print(f"ERROR: {e!s}")
        print(traceback.format_exc())
        raise HTTPException(
            status_code=500,
            detail=f"Unable to process the sustainability question: {e!s}"
        )
        
        
@app.get("/telemetry")
def get_telemetry(
    site_id: str = Query(...),
):
    query = f"""
        SELECT
            FORMAT_TIMESTAMP(
                '%Y-%m-%dT%H:%M:%SZ',
                timestamp
            ) AS timestamp,
            power_kw,
            occupancy
        FROM `{PROJECT_ID}.{DATASET}.{TELEMETRY_TABLE}`
        WHERE site_id = @site_id
          AND timestamp >= TIMESTAMP_SUB(
              CURRENT_TIMESTAMP(),
              INTERVAL 24 HOUR
          )
        ORDER BY timestamp ASC
        LIMIT 500
    """

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter(
                "site_id", "STRING", site_id
            )
        ]
    )

    rows = bq_client.query(
        query,
        job_config=job_config
    ).result()

    readings = [
        {
            "timestamp": row["timestamp"],
            "power_kw": row["power_kw"],
            "occupancy": row["occupancy"],
        }
        for row in rows
    ]

    return {
        "site_id": site_id,
        "period": "last 24 hours",
        "reading_count": len(readings),
        "readings": readings,
    }