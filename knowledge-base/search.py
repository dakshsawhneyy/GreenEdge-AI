import os

import vertexai

from google.cloud import bigquery
from vertexai.language_models import (
    TextEmbeddingInput,
    TextEmbeddingModel,
)

PROJECT_ID = os.environ["GCP_PROJECT_ID"]
REGION = os.environ.get("GCP_REGION", "asia-south1")
DATASET = os.environ.get("BQ_DATASET", "greenedge_dev")
TABLE = os.environ.get("BQ_TABLE", "knowledge_chunks")

vertexai.init(
    project=PROJECT_ID,
    location=REGION,
)

model = TextEmbeddingModel.from_pretrained(
    "text-embedding-005"
)

client = bigquery.Client(
    project=PROJECT_ID
)


def embed_query(question):
    query_input = TextEmbeddingInput(
        question,
        task_type="RETRIEVAL_QUERY",
    )

    result = model.get_embeddings(
        [query_input]
    )

    return result[0].values


def search_knowledge(question):
    query_embedding = embed_query(question)

    table_id = f"{PROJECT_ID}.{DATASET}.{TABLE}"

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

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ArrayQueryParameter(
                "query_embedding",
                "FLOAT64",
                query_embedding,
            )
        ]
    )

    results = client.query(
        sql,
        job_config=job_config,
    ).result()

    for row in results:
        print("\nSource:", row.source)
        print("Distance:", round(row.distance, 4))
        print("Content:", row.content)
        print("-" * 60)


if __name__ == "__main__":
    question = input("Ask a sustainability question: ")

    search_knowledge(question)