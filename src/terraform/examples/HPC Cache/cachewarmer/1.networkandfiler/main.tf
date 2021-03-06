// customize the simple VM by editing the following local variables
locals {
  // the region of the deployment
  location = "eastus"
  network_resource_group_name = "network_resource_group"
  vm_admin_username = "azureuser"
  // use either SSH Key data or admin password, if ssh_key_data is specified
  // then admin_password is ignored
  vm_admin_password = "ReplacePassword$"
  // if you use SSH key, ensure you have ~/.ssh/id_rsa with permission 600
  // populated where you are running terraform
  vm_ssh_key_data = null //"ssh-rsa AAAAB3...."

  // nfs filer details
  filer_location = "westus2"
  filer_resource_group_name = "filer_resource_group"
  // more filer sizes listed at https://github.com/Azure/Avere/tree/main/src/terraform/modules/nfs_filer
  filer_size = "Standard_D2s_v3" 
}

terraform {
  required_version = ">= 0.14.0,< 0.16.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// the render network
module "network" {
  source = "github.com/Azure/Avere/src/terraform/modules/render_network"
  resource_group_name = local.network_resource_group_name
  location = local.location
}

resource "azurerm_resource_group" "nfsfiler" {
  name     = local.filer_resource_group_name
  location = local.filer_location
}

resource "azurerm_virtual_network" "filervnet" {
  name                = "filervnet"
  address_space       = ["192.168.254.240/29"]
  location            = azurerm_resource_group.nfsfiler.location
  resource_group_name = azurerm_resource_group.nfsfiler.name

  // this subnet holds the cloud cache, there should be one cloud cache per subnet
  subnet {
    name           = "filersubnet"
    address_prefix = "192.168.254.240/29"
  }
}

resource "azurerm_virtual_network_peering" "peer-to-filer" {
  name                      = "peertofiler"
  resource_group_name       = module.network.vnet_resource_group
  virtual_network_name      = module.network.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.filervnet.id
}

resource "azurerm_virtual_network_peering" "peer-from-filer" {
  name                      = "peerfromfiler"
  resource_group_name       = azurerm_virtual_network.filervnet.resource_group_name
  virtual_network_name      = azurerm_virtual_network.filervnet.name
  remote_virtual_network_id = module.network.vnet_id
}

// the ephemeral filer
module "nasfiler1" {
  source = "github.com/Azure/Avere/src/terraform/modules/nfs_filer"
  resource_group_name = azurerm_resource_group.nfsfiler.name
  location = azurerm_resource_group.nfsfiler.location
  admin_username = local.vm_admin_username
  admin_password = local.vm_admin_password
  ssh_key_data = local.vm_ssh_key_data
  vm_size = local.filer_size
  unique_name = "nasfiler1"

  // network details
  virtual_network_resource_group = azurerm_virtual_network.filervnet.resource_group_name
  virtual_network_name = azurerm_virtual_network.filervnet.name
  virtual_network_subnet_name = tolist(azurerm_virtual_network.filervnet.subnet)[0].name

  depends_on = [
    azurerm_resource_group.nfsfiler,
    azurerm_virtual_network.filervnet.subnet,
  ]
}

output "filer_username" {
  value = module.nasfiler1.admin_username
}

output "filer_address" {
  value = module.nasfiler1.primary_ip
}

output "filer_export" {
  value = module.nasfiler1.core_filer_export
}

output "hpccache_network_resource_group_name" {
  value = module.network.vnet_resource_group
}

output "hpccache_network_name" {
  value = module.network.vnet_name
}

output "hpccache_jumpbox_subnet_name" {
  value = module.network.jumpbox_subnet_name
}

output "hpccache_jumpbox_subnet_id" {
  value = module.network.jumpbox_subnet_id
}

output "hpccache_cache_subnet_name" {
  value = module.network.cloud_cache_subnet_name
}

output "hpccache_cache_subnet_id" {
  value = module.network.cloud_cache_subnet_id
}

output "hpccache_render_subnet_name" {
  value = module.network.render_clients1_subnet_name
}
