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

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "ua_identity" {
  location            = azurerm_resource_group.main.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.main.name
}

module "avm_res_keyvault_vault" {
  source                      = "Azure/avm-res-keyvault-vault/azurerm"
  version                     = ">= 0.5.0"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  name                        = module.naming.key_vault.name_unique
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  enabled_for_disk_encryption = true
  network_acls = {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  role_assignments = {
    deployment_user_secrets = {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }

}


module "avm-res-compute-virtualmachine" {
  source                                 = "Azure/avm-res-compute-virtualmachine/azurerm"
  version                                = "0.10.0"
  resource_group_name                    = azurerm_resource_group.main.name
  location                               = var.primary_region
  name                                   = module.naming.virtual_machine.name_unique
  enable_telemetry                       = false
  zone                                   = "1"
  virtualmachine_os_type                 = "Windows"
  virtualmachine_sku_size                = "Standard_B2ms"
  admin_credential_key_vault_resource_id = module.avm_res_keyvault_vault.resource.id

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.ua_identity.id]
  }

  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          subnet_id                     = module.avm-res-network-virtualnetwork.subnets["subnet0"].id
          private_ip_address_allocation = "Dynamic"
        }
      }
    }

  }
}
