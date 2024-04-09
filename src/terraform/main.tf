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
  enable_telemetry              = false
  virtual_network_address_space = ["10.0.0.0/16"]
  virtual_network_dns_servers = {
    dns_servers = ["8.8.8.8"]
  }

}

module "avm-res-compute-virtualmachine" {
  source                  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version                 = "0.10.0"
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.primary_region
  name                    = module.naming.virtual_machine.name
  zone                    = "1"
  virtualmachine_sku_size = "Standard_B2ms"
}
