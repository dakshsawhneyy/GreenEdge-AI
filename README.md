# GreenEdge AI

## Multi-Cloud Sustainability Operations Copilot

GreenEdge AI is a capstone project exploring how edge telemetry,
multi-cloud infrastructure, analytics, and retrieval-augmented
generation can support sustainability operations.

The planned platform uses a Python sensor simulator and AWS IoT
Core for telemetry ingestion, Google Cloud for data processing and
AI, and Azure Static Web Apps for the user interface.

The project focuses on evidence-backed recommendations, measurable
energy data, responsible AI behavior, infrastructure as code,
and cost-conscious cloud design.

## Project status

Phase 1: Architecture and initial repository foundation.

Cloud resources and integrations will be implemented and verified
progressively across the ten project phases.

## Documentation

- [Architecture](docs/architecture.md)
- [Telemetry data contract](docs/data-contract.md)

## Development principles

- Treat synthetic data as synthetic.
- Separate structured telemetry from document retrieval.
- Avoid long-lived cloud credentials.
- Make cloud costs and resource cleanup part of the design.
- Verify integrations before claiming they work.