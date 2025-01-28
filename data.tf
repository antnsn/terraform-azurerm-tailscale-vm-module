# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# If using existing VNet/Subnet, get their data
data "azurerm_virtual_network" "existing" {
  count               = var.create_vnet ? 0 : 1
  name                = var.existing_vnet_name
  resource_group_name = local.resource_group_name
}

data "azurerm_subnet" "existing" {
  count                = var.create_vnet ? 0 : 1
  name                 = var.existing_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = local.resource_group_name
}

# Get current subscription
data "azurerm_subscription" "current" {}

# Data source for the PowerShell script
data "local_file" "start_stop_script" {
  filename = "${path.module}/scripts/start-stop.ps1"
}