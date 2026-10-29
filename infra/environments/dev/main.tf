locals {
  project_name = "greenedge-ai"
  environment  = "dev"

  cloud_responsibilities = {
    aws   = "iot-ingestion"
    gcp   = "analytics-and-ai"
    azure = "frontend-hosting"
  }
}

resource "terraform_data" "project_foundation" {
  input = {
    project          = local.project_name
    environment      = local.environment
    responsibilities = local.cloud_responsibilities
  }
}