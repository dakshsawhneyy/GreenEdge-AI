terraform {
  backend "s3" {
    bucket = "greenedge-ai-statefile-bucket"
    key    = "green-edge-ai/terraform.tfstate"
    region = "ap-south-1"
    # Modern S3 Native State Locking (Terraform v1.9.0+)
    use_lockfile = true
  }
}