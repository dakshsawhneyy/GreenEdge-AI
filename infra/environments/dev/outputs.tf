output "project_name" {
  description = "GreenEdge AI project name"
  value       = terraform_data.project_foundation.output.project
}

output "environment" {
  description = "Deployment environment"
  value       = terraform_data.project_foundation.output.environment
}

output "cloud_responsibilities" {
  description = "Planned responsibility of each cloud"
  value       = terraform_data.project_foundation.output.responsibilities
}