variable "aws_region" {
  description = "AWS region for GreenEdge AI"
  type        = string
  default     = "ap-south-1"
}

variable "gcp_project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "gcp_region" {
  description = "Google Cloud region"
  type        = string
  default     = "asia-south1"
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "device_csr_path" {
  description = "Path to the locally generated device CSR"
  type        = string
  default     = "certs/device.csr"
}

variable "aws_account_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = "greenedge-ai"
}

variable "static_web_app_name" {
  description = "Globally unique name for the Static Web App"
  type        = string
}

variable "billing_account_id" {
  type      = string
  sensitive = true
}

variable "project_number" {
  type = string
}

variable "frontend_origin" {
  description = "Production Azure Static Web Apps origin for CORS (e.g., https://your-app.azurestaticapps.net)"
  type        = string
  default     = ""
}
