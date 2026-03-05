variable "location" {
  description = "Azure region for the resource group"
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group managed by Terraform (referenced by Crossplane)"
  type        = string
  default     = "crossplane-demo-rg"
}

variable "sp_name" {
  description = "Display name of the Service Principal used by Crossplane"
  type        = string
  default     = "crossplane-sp"
}
