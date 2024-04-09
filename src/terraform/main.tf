resource "random_string" "main" {
  length  = 8
  upper   = false
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}-${random_string.main.result}"
  location = var.primary_region
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

locals {
  subnets = {
    for i in range(3) : "subnet${i}" => {
      address_prefixes = [cidrsubnet(local.virtual_network_address_space, 8, i)]
    }
  }
  virtual_network_address_space = "10.0.0.0/16"
}

module "avm-res-network-virtualnetwork" {
  source                        = "Azure/avm-res-network-virtualnetwork/azurerm"
  version                       = "0.1.4"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.primary_region
  name                          = module.naming.virtual_network.name
  subnets                       = local.subnets
  virtual_network_address_space = local.virtual_network_address_space
}
