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