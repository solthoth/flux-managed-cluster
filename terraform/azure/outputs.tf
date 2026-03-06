output "client_id" {
  description = "Service Principal Application (client) ID — used in Crossplane credentials JSON"
  value       = azuread_application.crossplane.client_id
  sensitive   = true
}

output "client_secret" {
  description = "Service Principal password — used in Crossplane credentials JSON"
  value       = azuread_service_principal_password.crossplane.value
  sensitive   = true
}

output "tenant_id" {
  description = "Azure Active Directory Tenant ID — used in Crossplane credentials JSON"
  value       = data.azuread_client_config.current.tenant_id
  sensitive   = true
}

output "subscription_id" {
  description = "Azure Subscription ID — used in Crossplane credentials JSON"
  value       = data.azurerm_subscription.current.subscription_id
  sensitive   = true
}
