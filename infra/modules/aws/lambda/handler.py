import json
import logging
import os
from datetime import datetime, timezone

import google.auth
from google.cloud import pubsub_v1

logger = logging.getLogger()
logger.setLevel(logging.INFO)

PROJECT_ID = os.environ["GCP_PROJECT_ID"]
TOPIC_ID = os.environ["GCP_PUBSUB_TOPIC"]

# ADC reads aws-wif-config.json.
# The Google authentication library exchanges the Lambda's
# temporary AWS credentials for short-lived Google credentials.
credentials, _ = google.auth.default(
    scopes=["https://www.googleapis.com/auth/pubsub"]
)

publisher = pubsub_v1.PublisherClient(
    credentials=credentials
)

topic_path = publisher.topic_path(
    PROJECT_ID,
    TOPIC_ID
)


def validate_event(event):
    required = [
        "event_id",
        "device_id",
        "site_id",
        "timestamp",
        "temperature_c",
        "humidity_pct",
        "power_kw",
        "occupancy",
    ]

    for field in required:
        if field not in event:
            raise ValueError(f"Missing field: {field}")

    if not isinstance(event["event_id"], str) or not event["event_id"]:
        raise ValueError("Invalid event_id")

    if not isinstance(event["device_id"], str) or not event["device_id"]:
        raise ValueError("Invalid device_id")

    if not isinstance(event["site_id"], str) or not event["site_id"]:
        raise ValueError("Invalid site_id")

    timestamp = datetime.fromisoformat(
        event["timestamp"].replace("Z", "+00:00")
    )

    if timestamp.tzinfo is None:
        raise ValueError("Timestamp must include timezone")

    if timestamp.utcoffset() != timezone.utc.utcoffset(timestamp):
        raise ValueError("Timestamp must be UTC")

    for field in [
        "temperature_c",
        "humidity_pct",
        "power_kw",
    ]:
        value = event[field]

        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError(f"Invalid numeric field: {field}")

    if not 0 <= event["humidity_pct"] <= 100:
        raise ValueError("Invalid humidity")

    if event["power_kw"] < 0:
        raise ValueError("Power cannot be negative")

    if isinstance(event["occupancy"], bool) or not isinstance(
        event["occupancy"], int
    ):
        raise ValueError("Occupancy must be an integer")

    if event["occupancy"] < 0:
        raise ValueError("Occupancy cannot be negative")


def lambda_handler(event, context):
    try:
        validate_event(event)

        payload = json.dumps(event).encode("utf-8")

        future = publisher.publish(
            topic_path,
            payload,
            event_id=event["event_id"],
            device_id=event["device_id"],
            site_id=event["site_id"],
        )

        message_id = future.result(timeout=15)

        logger.info(
            json.dumps({
                "status": "published",
                "event_id": event["event_id"],
                "pubsub_message_id": message_id,
                "topic": TOPIC_ID,
            })
        )

        return {
            "statusCode": 200,
            "message": "Telemetry published to Pub/Sub",
            "event_id": event["event_id"],
            "pubsub_message_id": message_id,
        }

    except Exception:
        logger.exception("Telemetry publishing failed")
        raise