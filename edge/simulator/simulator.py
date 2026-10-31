import argparse
import json
import random
import sys
import time
import uuid
from datetime import UTC, datetime


def utc_timestamp():
    """Return an ISO 8601 UTC timestamp."""
    return (
        datetime.now(UTC)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def generate_event(device_id, site_id, sequence, rng):
    """Generate one synthetic sensor event."""
    occupancy = rng.randint(0, 30)

    # Illustrative relationship: higher occupancy can increase
    # simulated power demand. This is not a physical building model.
    base_power = 1.5 + occupancy * 0.12
    power_kw = round(max(0.0, base_power + rng.uniform(-0.3, 0.5)), 2)

    # Sensor Generated Data
    return {
        "event_id": f"evt-{sequence:06d}-{uuid.uuid4().hex[:8]}",
        "device_id": device_id,
        "site_id": site_id,
        "timestamp": utc_timestamp(),
        "temperature_c": round(rng.uniform(22.0, 28.0), 1),
        "humidity_pct": round(rng.uniform(35.0, 65.0), 1),
        "power_kw": power_kw,
        "occupancy": occupancy,
    }


def validate_event(event):
    """Validate required fields, types, ranges and UTC timestamp."""
    required = {
        "event_id",
        "device_id",
        "site_id",
        "timestamp",
        "temperature_c",
        "humidity_pct",
        "power_kw",
        "occupancy",
    }

    if not isinstance(event, dict) or set(event) != required:
        return False, "Missing or unexpected fields"

    for field in ("event_id", "device_id", "site_id"):
        if not isinstance(event[field], str) or not event[field].strip():
            return False, f"{field} must be a non-empty string"

    timestamp = event["timestamp"]
    if not isinstance(timestamp, str):
        return False, "timestamp must be a string"

    try:
        parsed = datetime.fromisoformat(
            timestamp.replace("Z", "+00:00")
        )
        if parsed.tzinfo is None or parsed.utcoffset().total_seconds() != 0:
            return False, "timestamp must include UTC timezone"
        if not timestamp.endswith("Z"):
            return False, "timestamp must use the UTC Z suffix"
    except (ValueError, AttributeError):
        return False, "timestamp must be a valid ISO 8601 timestamp"

    temperature = event["temperature_c"]
    humidity = event["humidity_pct"]
    power = event["power_kw"]
    occupancy = event["occupancy"]

    # bool is a subclass of int in Python, so reject it explicitly.
    for field, value in (
        ("temperature_c", temperature),
        ("humidity_pct", humidity),
        ("power_kw", power),
    ):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return False, f"{field} must be numeric"

    if not -50 <= temperature <= 100:
        return False, "temperature_c is outside the allowed range"

    if not 0 <= humidity <= 100:
        return False, "humidity_pct must be between 0 and 100"

    if power < 0:
        return False, "power_kw cannot be negative"

    if isinstance(occupancy, bool) or not isinstance(occupancy, int):
        return False, "occupancy must be an integer"

    if occupancy < 0:
        return False, "occupancy cannot be negative"

    return True, "valid"


def main():
    parser = argparse.ArgumentParser(
        description="Generate GreenEdge AI synthetic telemetry."
    )
    parser.add_argument("--events", type=int, default=10)
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument(
        "--device-id",
        default="building-01-sensor-01",
    )
    parser.add_argument("--site-id", default="building-01")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument(
        "--output",
        default="-",
        help="Output JSONL file; use - for standard output",
    )
    args = parser.parse_args()

    if args.events < 1:
        parser.error("--events must be at least 1")
    if args.interval < 0:
        parser.error("--interval cannot be negative")
    if not args.device_id.strip() or not args.site_id.strip():
        parser.error("device and site IDs cannot be empty")

    rng = random.Random(args.seed)

    # Do not mix diagnostic messages with JSONL on stdout.
    output = (
        sys.stdout
        if args.output == "-"
        else open(args.output, "w", encoding="utf-8")
    )

    valid_count = 0
    try:
        for sequence in range(1, args.events + 1):
            event = generate_event(
                args.device_id, args.site_id, sequence, rng
            )
            valid, reason = validate_event(event)

            if not valid:
                print(
                    f"Rejected event {sequence}: {reason}",
                    file=sys.stderr,
                )
            else:
                output.write(json.dumps(event) + "\n")
                output.flush()
                valid_count += 1

            if sequence < args.events and args.interval > 0:
                time.sleep(args.interval)
    finally:
        if output is not sys.stdout:
            output.close()

    print(
        f"Generated {args.events}; valid: {valid_count}; "
        f"rejected: {args.events - valid_count}",
        file=sys.stderr,
    )

    if valid_count != args.events:
        sys.exit(1)


if __name__ == "__main__":
    main()
