# GreenEdge AI Architecture

## 1. Purpose

GreenEdge AI is a sustainability operations copilot that combines
synthetic IoT telemetry, cloud analytics, retrieval-augmented
generation, and a web dashboard.

It is designed to help users investigate energy consumption and
review evidence-backed sustainability recommendations.

## 2. Cloud responsibilities

- AWS: IoT ingestion, message routing, and event processing.
- Google Cloud: Pub/Sub, BigQuery, Cloud Run, and Vertex AI.
- Azure: React frontend hosting through Azure Static Web Apps.
- Terraform: infrastructure definitions and environment composition.
- GitHub Actions: testing, security checks, and deployment automation.

## 3. Telemetry data flow

1. A Python simulator generates sensor readings.
2. The simulator publishes events using MQTT over TLS.
3. AWS IoT Core authenticates the device and receives the message.
4. An IoT Rule routes the message to Lambda.
5. Lambda validates and forwards the event to Google Cloud Pub/Sub
   using a restricted federated identity.
6. Pub/Sub delivers the event to BigQuery.
7. BigQuery supports queries and sustainability calculations.

## 4. AI question-answering flow

1. The user submits a question through the React dashboard.
2. The frontend calls the Cloud Run API.
3. The API retrieves relevant telemetry from BigQuery.
4. The API retrieves relevant document passages using embeddings
   and vector search.
5. The API supplies the evidence to Vertex AI for generation.
6. The response includes supporting sources and distinguishes
   measured facts from estimates or hypotheses.

## 5. Security boundaries

- IoT devices have restricted permissions.
- AWS resources use least-privilege IAM policies.
- AWS-to-Google Cloud access uses workload identity federation.
- Cloud Run uses a dedicated runtime identity.
- Browser-facing API access is controlled and does not expose
  cloud credentials.
- Secrets and Terraform state must not be committed to Git.

## 6. Sustainability principles

- Use synthetic telemetry for the development environment.
- Control sensor frequency and unnecessary data transfer.
- Query structured data rather than sending large datasets
  into model prompts.
- Avoid unnecessary embedding and generation calls.
- Use documented, configurable emissions factors.
- Monitor resource usage and clean up unused cloud resources.

## 7. Known limitations

- The initial sensor data is simulated.
- AI output may be incomplete or incorrect and must be grounded
  in evidence.
- The platform provides recommendations, not autonomous
  control of physical equipment.
- Production availability, security, costs, and carbon benefits
  must be validated rather than assumed.

## 8. Target acceptance criteria

- Sensor events reach BigQuery through the ingestion pipeline.
- Telemetry can be queried and used for sustainability metrics.
- The assistant retrieves relevant documentation and telemetry.
- Answers include supporting references and acknowledge uncertainty.
- The frontend displays metrics and answers.
- CI/CD, monitoring, security, and cleanup procedures are documented
  and verified.