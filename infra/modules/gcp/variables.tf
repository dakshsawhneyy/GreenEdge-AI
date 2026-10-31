variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

# Lambda authenticating to gcp
variable "aws_account_id" {
  type = string
}

variable "aws_lambda_role_name" {
  type = string
}


variable "billing_account_id" {
  type      = string
  sensitive = true
}

variable "project_number" {
  type = string
}

variable "github_repository" {
  description = "GitHub repository in OWNER/REPO format"
  type        = string
}

variable "github_deployment_service_account_id" {
  type    = string
  default = "greenedge-github-deployer"
}

variable "bigquery_dataset_id" {
  type = string
  default = "greenedge_dev"
}

variable "frontend_origin" {
  type        = string
  description = "Production Azure Static Web Apps origin for CORS"
  default     = ""
}
