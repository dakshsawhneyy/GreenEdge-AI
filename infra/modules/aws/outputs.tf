output "iot_endpoint" {
  value = data.aws_iot_endpoint.data.endpoint_address
}

output "thing_name" {
  value = aws_iot_thing.sensor.name
}

output "device_certificate_pem" {
  value = aws_iot_certificate.sensor.certificate_pem
}

output "lambda_function_name" {
  value = aws_lambda_function.telemetry.function_name
}

output "telemetry_topic" {
  value = var.topic
}

output "lambda_role_arn" {
  description = "IAM role assumed by the telemetry Lambda"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda IAM role (not ARN, just the name)"
  value       = aws_iam_role.lambda.name
}
