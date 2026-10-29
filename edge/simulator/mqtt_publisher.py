import argparse
import json
import os
import time

from awsiot import mqtt_connection_builder
from awscrt import mqtt

from simulator import generate_event, validate_event
import random


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--events", type=int, default=5)
    parser.add_argument("--interval", type=float, default=2)
    args = parser.parse_args()

    if args.events < 1 or args.interval < 0:
        parser.error("events must be positive and interval non-negative")

    endpoint = os.environ["AWS_IOT_ENDPOINT"]
    cert = os.environ["AWS_IOT_CERT"]
    key = os.environ["AWS_IOT_KEY"]
    ca = os.environ["AWS_IOT_CA"]

    client_id = "greenedge-ai-dev-sensor-01"
    topic = "greenedge/building-01/telemetry"

    connection = mqtt_connection_builder.mtls_from_path(
        endpoint=endpoint,
        cert_filepath=cert,
        pri_key_filepath=key,
        ca_filepath=ca,
        client_id=client_id,
        clean_session=True,
        keep_alive_secs=30,
    )

    print("Connecting to AWS IoT Core...")
    connection.connect().result(timeout=15)
    print("Connected.")

    rng = random.Random()

    try:
        for sequence in range(1, args.events + 1):
            event = generate_event(
                "building-01-sensor-01",
                "building-01",
                sequence,
                rng,
            )
            valid, reason = validate_event(event)

            if not valid:
                raise ValueError(f"Invalid generated event: {reason}")

            packet_id = connection.publish(
                topic=topic,
                payload=json.dumps(event),
                qos=mqtt.QoS.AT_LEAST_ONCE,
            )



            print(f"Published {event['event_id']}")

            if sequence < args.events:
                time.sleep(args.interval)
    finally:
        connection.disconnect().result(timeout=10)
        print("Disconnected.")


if __name__ == "__main__":
    main()
