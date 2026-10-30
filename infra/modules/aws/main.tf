data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Generate WIF configuration file for Lambda
resource "local_file" "wif_config" {
  filename = "${path.module}/lambda/aws-wif-config.json"

  content = jsonencode({
    type                              = "external_account"
    audience                          = "//iam.googleapis.com/projects/${var.gcp_project_number}/locations/global/workloadIdentityPools/${var.workload_identity_pool_id}/providers/${var.workload_identity_provider_id}"
    subject_token_type                = "urn:ietf:params:aws:token-type:aws4_request"
    token_url                         = "https://sts.googleapis.com/v1/token"
    service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${var.lambda_publisher_sa_email}:generateAccessToken"
    credential_source = {
      environment_id                 = "aws1"
      regional_cred_verification_url = "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15"
    }
  })
}

data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

resource "aws_iot_thing" "sensor" {
  name = "${var.project_name}-${var.environment}-sensor-01"
}

resource "aws_iot_certificate" "sensor" {
  csr    = var.device_csr
  active = true
}

resource "aws_iot_thing_principal_attachment" "sensor" {
  thing     = aws_iot_thing.sensor.name
  principal = aws_iot_certificate.sensor.arn
}

resource "aws_iot_policy" "sensor" {
  name = "${var.project_name}-${var.environment}-sensor-publish"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iot:Connect"]
        Resource = "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/${aws_iot_thing.sensor.name}"
      },
      {
        Effect   = "Allow"
        Action   = ["iot:Publish"]
        Resource = "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${var.topic}"
      }
    ]
  })
}

resource "aws_iot_policy_attachment" "sensor" {
  policy = aws_iot_policy.sensor.name
  target = aws_iot_certificate.sensor.arn
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-telemetry-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-telemetry"
  retention_in_days = 7
}

resource "aws_lambda_function" "telemetry" {
  function_name    = "${var.project_name}-${var.environment}-telemetry"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      GOOGLE_APPLICATION_CREDENTIALS = "/var/task/aws-wif-config.json"
      GCP_PROJECT_ID                 = var.gcp_project_id
      GCP_PUBSUB_TOPIC               = var.gcp_topic_id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

resource "aws_lambda_permission" "iot" {
  statement_id  = "AllowIoTRuleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telemetry.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.telemetry.arn
}

resource "aws_iot_topic_rule" "telemetry" {
  name        = replace("${var.project_name}_${var.environment}_telemetry", "-", "_")
  enabled     = true
  sql         = "SELECT * FROM '${var.topic}'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.telemetry.arn
  }
}