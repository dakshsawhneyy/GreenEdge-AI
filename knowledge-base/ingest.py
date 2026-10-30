import hashlib
import os
from datetime import datetime, timezone
from pathlib import Path

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

CORPUS_DIR = Path(__file__).parent / "sustainability"

# Initialize Vertex AI
vertexai.init(
    project=PROJECT_ID,
    location=REGION,
)

# Initialize embedding model
model = TextEmbeddingModel.from_pretrained(
    "text-embedding-005"
)

# Initialize BigQuery client
bq_client = bigquery.Client(
    project=PROJECT_ID
)

table_id = f"{PROJECT_ID}.{DATASET}.{TABLE}"


def chunk_text(text, chunk_size=150, overlap=30):
    words = text.split()

    chunks = []
    start = 0

    while start < len(words):
        end = start + chunk_size

        chunk = " ".join(words[start:end])

        if chunk.strip():
            chunks.append(chunk)

        if end >= len(words):
            break

        start = end - overlap

    return chunks


def generate_embedding(text):
    embedding_input = TextEmbeddingInput(
        text,
        task_type="RETRIEVAL_DOCUMENT",
    )

    result = model.get_embeddings(
        [embedding_input]
    )

    return result[0].values


def ingest_document(file_path):
    content = file_path.read_text(
        encoding="utf-8"
    )

    chunks = chunk_text(content)

    rows = []

    for index, chunk in enumerate(chunks):
        chunk_id = hashlib.sha256(
            f"{file_path.name}:{index}:{chunk}".encode()
        ).hexdigest()

        embedding = generate_embedding(chunk)

        rows.append({
            "chunk_id": chunk_id,
            "source": file_path.name,
            "content": chunk,
            "embedding": embedding,
            "created_at": datetime.now(
                timezone.utc
            ).isoformat(),
        })

    if rows:
        errors = bq_client.insert_rows_json(
            table_id,
            rows,
        )

        if errors:
            raise RuntimeError(
                f"BigQuery insertion failed: {errors}"
            )

    print(
        f"Ingested {len(rows)} chunks from "
        f"{file_path.name}"
    )


def main():
    files = list(CORPUS_DIR.glob("*.md"))

    if not files:
        print("No Markdown documents found.")
        return

    for file_path in files:
        ingest_document(file_path)


if __name__ == "__main__":
    main()