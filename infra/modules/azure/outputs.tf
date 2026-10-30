output "frontend_url" {
  description = "Public URL of the Azure Static Web App"
  value       = "https://${azurerm_static_web_app.frontend.default_host_name}"
}

output "resource_group_name" {
  value = azurerm_resource_group.frontend.name
}