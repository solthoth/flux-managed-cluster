terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

# --------------------------------------------------------------------------- #
# Data sources                                                                  #
# --------------------------------------------------------------------------- #

data "azurerm_subscription" "current" {}
data "azuread_client_config" "current" {}

# --------------------------------------------------------------------------- #
# Resource Group                                                                #
# --------------------------------------------------------------------------- #

resource "azurerm_resource_group" "crossplane" {
  name     = var.resource_group_name
  location = var.location
}

# --------------------------------------------------------------------------- #
# Service Principal                                                             #
# --------------------------------------------------------------------------- #

resource "azuread_application" "crossplane" {
  display_name = var.sp_name
}

resource "azuread_service_principal" "crossplane" {
  client_id = azuread_application.crossplane.client_id
}

resource "azuread_service_principal_password" "crossplane" {
  service_principal_id = azuread_service_principal.crossplane.id
}

# --------------------------------------------------------------------------- #
# Role assignment — Contributor on the Resource Group                          #
# --------------------------------------------------------------------------- #

resource "azurerm_role_assignment" "crossplane_contributor" {
  scope                = azurerm_resource_group.crossplane.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.crossplane.object_id
}
