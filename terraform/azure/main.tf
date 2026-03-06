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
    local = {
      source = "hashicorp/local"
      version = "~> 2.5"
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
# Role assignment — Contributor on the Subscription                            #
#                                                                               #
# Scoped to the subscription so Crossplane can create new Resource Groups      #
# per claim (e.g. demo-queue-rg, hello-world-api-queue-rg). A resource-group-  #
# scoped role cannot grant permission to create sibling resource groups.       #
# --------------------------------------------------------------------------- #

resource "azurerm_role_assignment" "crossplane_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.crossplane.object_id
}

# --------------------------------------------------------------------------- #
# Create a local sensitive file containing the Crossplane service principal   #
# credentials                                                                 #
#                                                                             #
# This file is later encrypted using SOPS to produce a secure JSON file that  #
# can be used by Crossplane to authenticate with Azure.                       #
# --------------------------------------------------------------------------- #

resource "local_sensitive_file" "crossplane_sp_plaintext" {
  filename = local.plaintext_file
  content  = local.crossplane_sp_json
}

resource "terraform_data" "encrypt_crossplane_sp" {
  triggers_replace = {
    content_sha = sha256(local.crossplane_sp_json)
    out_file    = local.encrypted_file
  }

  depends_on = [local_sensitive_file.crossplane_sp_plaintext]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      mkdir -p "${path.module}/generated"
      SOPS_CONFIG="${path.module}/../../.sops.yaml" \
      sops --encrypt \
        --input-type json \
        --output-type json \
        --filename-override "${local.encrypted_file}" \
        "${local.plaintext_file}" > "${local.encrypted_file}"

      rm -f "${local.plaintext_file}"
    EOT
  }
}
