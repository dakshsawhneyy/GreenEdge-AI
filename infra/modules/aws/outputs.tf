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