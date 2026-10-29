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
