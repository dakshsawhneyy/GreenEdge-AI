# locals {
#   project_name = "greenedge-ai"
#   environment  = "dev"

#   cloud_responsibilities = {
#     aws   = "iot-ingestion"
#     gcp   = "analytics-and-ai"
#     azure = "frontend-hosting"
#   }
# }

# resource "terraform_data" "project_foundation" {
#   input = {
#     project          = local.project_name
#     environment      = local.environment
#     responsibilities = local.cloud_responsibilities
#   }
# }

module "aws_ingestion" {
  source = "../../modules/aws"

  project_name = "greenedge-ai"
  environment  = "dev"
  device_csr   = file(var.device_csr_path)

  gcp_project_id = var.gcp_project_id
  gcp_topic_id   = "greenedge-dev-telemetry"

  gcp_project_number            = module.gcp_pipeline.gcp_project_number
  workload_identity_pool_id     = "greenedge-aws-pool"
  workload_identity_provider_id = "greenedge-aws-provider"
  lambda_publisher_sa_email     = module.gcp_pipeline.lambda_publisher_service_account
}

module "gcp_pipeline" {
  source = "../../modules/gcp"

  project_id           = var.gcp_project_id
  region               = var.gcp_region
  environment          = "dev"
  aws_account_id       = var.aws_account_id
  aws_lambda_role_name = module.aws_ingestion.lambda_role_name
  billing_account_id = var.billing_account_id
  project_number = var.project_number
  github_repository = "dakshsawhneyy/GreenEdge-AI"
}


# Azure Integration
module "azure_frontend" {
  source              = "../../modules/azure"
  project_name        = var.project_name
  environment         = "dev"
  static_web_app_name = var.static_web_app_name
}