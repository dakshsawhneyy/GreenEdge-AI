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
