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