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

output "resource_group_name" {
  description = "Resource Group name — set this in crossplane/overlays/<env>/azure-storage/storage-account.yaml"
  value       = azurerm_resource_group.crossplane.name
}

output "location" {
  description = "Azure region — set this in crossplane/overlays/<env>/azure-storage/storage-account.yaml"
  value       = azurerm_resource_group.crossplane.location
}
