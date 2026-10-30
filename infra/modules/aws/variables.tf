variable "project_name" {
  type    = string
  default = "greenedge-ai"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "device_csr" {
  description = "Public certificate signing request"
  type        = string
}

variable "topic" {
  type    = string
  default = "greenedge/building-01/telemetry"
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_topic_id" {
  type = string
}

variable "gcp_project_number" {
  description = "GCP project number for WIF"
  type        = string
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
}

variable "lambda_publisher_sa_email" {
  description = "Service account email for Lambda publisher"
  type        = string
}
