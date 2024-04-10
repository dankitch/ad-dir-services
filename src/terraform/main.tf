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
    for i in range(1) : "subnet${i}" => {
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
  name                          = "${module.naming.virtual_network.name}-${var.primary_region}"
  subnets                       = local.subnets
  enable_telemetry              = false
  virtual_network_address_space = ["10.0.0.0/16"]
  virtual_network_dns_servers = {
    dns_servers = ["8.8.8.8"]
  }

}

# module "avm-res-compute-virtualmachine" {
#   source                  = "Azure/avm-res-compute-virtualmachine/azurerm"
#   version                 = "0.10.0"
#   resource_group_name     = azurerm_resource_group.main.name
#   location                = var.primary_region
#   name                    = module.naming.virtual_machine.name_unique
#   enable_telemetry        = false
#   zone                    = "1"
#   virtualmachine_sku_size = "Standard_B2ms"

#   source_image_reference = {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2022-datacenter-g2"
#     version   = "latest"
#   }

#   network_interfaces = {
#     network_interface_1 = {
#       name = module.naming.network_interface.name_unique
#       ip_configurations = {
#         ip_configuration_1 = {
#           name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
#           subnet_id                     = module.avm-res-network-virtualnetwork.subnets["subnet0"].id
#           private_ip_address_allocation = "Dynamic"
#         }
#       }
#     }

#   }
# }
