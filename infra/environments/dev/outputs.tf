output "iot_endpoint" {
  value = module.aws_ingestion.iot_endpoint
}

# ADD THIS:
output "device_certificate_pem" {
  value     = module.aws_ingestion.device_certificate_pem
  sensitive = true
}

# OPTIONALLY ADD THESE TOO (useful):
output "thing_name" {
  value = module.aws_ingestion.thing_name
}

output "lambda_function_name" {
  value = module.aws_ingestion.lambda_function_name
}

output "telemetry_topic" {
  value = module.aws_ingestion.telemetry_topic
}


# GCP Outputs
output "gcp_pubsub_topic" {
  value = module.gcp_pipeline.pubsub_topic_id
}

output "gcp_bigquery_dataset" {
  value = module.gcp_pipeline.bigquery_dataset
}

output "gcp_bigquery_table" {
  value = module.gcp_pipeline.bigquery_table
}


### WIF outputs

# WIF Configuration Outputs (needed for Lambda)
output "workload_identity_provider_name" {
  value = module.gcp_pipeline.workload_identity_provider_name
}

output "lambda_publisher_service_account" {
  value = module.gcp_pipeline.lambda_publisher_service_account
}

output "workload_identity_pool_name" {
  value = module.gcp_pipeline.workload_identity_pool_name
}

output "gcp_project_number" {
  value = module.gcp_pipeline.gcp_project_number
}
