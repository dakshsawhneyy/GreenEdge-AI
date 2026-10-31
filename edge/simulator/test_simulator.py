import random
import unittest

from simulator import generate_event, validate_event


class SimulatorTests(unittest.TestCase):
    def setUp(self):
        self.event = generate_event(
            "sensor-01", "building-01", 1, random.Random(42)
        )

    def test_generated_event_is_valid(self):
        valid, reason = validate_event(self.event)
        self.assertTrue(valid, reason)

    def test_negative_power_is_rejected(self):
        event = self.event.copy()
        event["power_kw"] = -1
        self.assertFalse(validate_event(event)[0])

    def test_humidity_above_100_is_rejected(self):
        event = self.event.copy()
        event["humidity_pct"] = 140
        self.assertFalse(validate_event(event)[0])

    def test_negative_occupancy_is_rejected(self):
        event = self.event.copy()
        event["occupancy"] = -1
        self.assertFalse(validate_event(event)[0])

    def test_invalid_timestamp_is_rejected(self):
        event = self.event.copy()
        event["timestamp"] = "not-a-timestamp"
        self.assertFalse(validate_event(event)[0])

    def test_missing_field_is_rejected(self):
        event = self.event.copy()
        del event["device_id"]
        self.assertFalse(validate_event(event)[0])


if __name__ == "__main__":
    unittest.main()