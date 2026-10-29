import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    required = {
        "event_id", "device_id", "site_id", "timestamp",
        "temperature_c", "humidity_pct", "power_kw", "occupancy"
    }

    if not isinstance(event, dict) or not required.issubset(event):
        raise ValueError("Telemetry missing required fields")

    for field in ("event_id", "device_id", "site_id"):
        if not isinstance(event[field], str) or not event[field].strip():
            raise ValueError(f"Invalid {field}")

    try:
        timestamp = event["timestamp"]
        parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        if parsed.utcoffset() is None or not timestamp.endswith("Z"):
            raise ValueError("Timestamp must be UTC")
    except (ValueError, AttributeError, TypeError):
        raise ValueError("Invalid UTC timestamp")

    for field in ("temperature_c", "humidity_pct", "power_kw"):
        value = event[field]
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError(f"Invalid {field}")

    if not -50 <= event["temperature_c"] <= 100:
        raise ValueError("Temperature out of range")
    if not 0 <= event["humidity_pct"] <= 100:
        raise ValueError("Humidity out of range")
    if event["power_kw"] < 0:
        raise ValueError("Power cannot be negative")

    occupancy = event["occupancy"]
    if isinstance(occupancy, bool) or not isinstance(occupancy, int):
        raise ValueError("Occupancy must be an integer")
    if occupancy < 0:
        raise ValueError("Occupancy cannot be negative")

    logger.info(json.dumps({
        "message": "Telemetry accepted",
        "event_id": event["event_id"],
        "device_id": event["device_id"],
        "site_id": event["site_id"],
        "power_kw": event["power_kw"],
        "occupancy": occupancy,
    }))

    return {"statusCode": 200, "body": "Telemetry accepted"}