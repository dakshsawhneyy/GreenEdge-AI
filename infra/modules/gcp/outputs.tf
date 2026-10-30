output "pubsub_topic_id" {
  value = google_pubsub_topic.telemetry.id
}

output "bigquery_dataset" {
  value = google_bigquery_dataset.telemetry.dataset_id
}

output "bigquery_table" {
  value = google_bigquery_table.telemetry.table_id
}


# WIF Outputs
output "workload_identity_pool_name" {
  value = google_iam_workload_identity_pool.aws.name
}

output "workload_identity_provider_name" {
  value = google_iam_workload_identity_pool_provider.aws.name
}

output "lambda_publisher_service_account" {
  value = google_service_account.lambda_publisher.email
}

output "gcp_project_number" {
  value = data.google_project.current.number
}

output "knowledge_table" {
  value = google_bigquery_table.knowledge_chunks.table_id
}