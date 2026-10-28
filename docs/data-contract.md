# Telemetry Data Contract

## Purpose

This contract defines the sensor event format shared by the edge
simulator, AWS ingestion layer, and Google Cloud analytics pipeline.

All readings generated during development are synthetic.

## Event fields

| Field | Type | Description |
|---|---|---|
| event_id | string | Unique event identifier |
| schema_version | string | Version of the event schema |
| event_type | string | Event category; initially sensor.telemetry |
| site_id | string | Identifier of the monitored site |
| device_id | string | Identifier of the simulated device |
| observed_at | string | UTC timestamp in ISO 8601 format |
| interval_seconds | integer | Duration of the measurement interval |
| power_kw | number | Average power during the interval |
| energy_kwh_delta | number | Energy consumed in the interval |
| temperature_c | number | Temperature in degrees Celsius |
| humidity_pct | number | Relative humidity, from 0 to 100 |
| occupancy_count | integer | Non-negative occupancy count |

## Validation rules

- event_id must be unique for each generated event.
- observed_at must include a UTC timezone indicator.
- interval_seconds must be greater than zero.
- power_kw and energy_kwh_delta must be non-negative.
- humidity_pct must be between 0 and 100.
- occupancy_count must be a non-negative integer.
- energy_kwh_delta should be consistent with average power
  and the measurement interval, within the simulator's precision.
- Synthetic readings must not be presented as real building data.

## Energy relationship

For average power over the measurement interval:

energy_kwh_delta = power_kw * interval_seconds / 3600

## Evolution policy

Additive optional fields may be introduced with backward
compatibility in mind. Changes to field meaning, units, or
required fields must be reviewed and documented as a schema
change.

## Initial event

See ../edge/simulator/sample-event.json.