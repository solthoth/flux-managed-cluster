locals {
  crossplane_sp_json = jsonencode({
    clientId                       = azuread_application.crossplane.client_id
    clientSecret                   = azuread_service_principal_password.crossplane.value
    tenantId                       = data.azuread_client_config.current.tenant_id
    subscriptionId                 = data.azurerm_subscription.current.subscription_id
    activeDirectoryEndpointUrl     = "https://login.microsoftonline.com"
    resourceManagerEndpointUrl     = "https://management.azure.com/"
    activeDirectoryGraphResourceId = "https://graph.windows.net/"
    sqlManagementEndpointUrl       = "https://management.core.windows.net:8443/"
    galleryEndpointUrl             = "https://gallery.azure.com/"
    managementEndpointUrl          = "https://management.core.windows.net/"
  })

  plaintext_file = "${path.module}/generated/azure-sp-creds.json"
  encrypted_file = "${path.module}/generated/azure-sp-creds.enc.json"
}