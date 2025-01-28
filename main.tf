# Resource Groups
locals {
  # Main resource group name (for shared resources like VNet)
  resource_group_name = var.create_resource_group ? azurerm_resource_group.main[0].name : var.existing_resource_group_name

  # Automation resource group name
  automation_rg_name = coalesce(var.automation_resource_group_name, "${var.project_name}-automation-rg")

  # VM resource group mapping
  vm_resource_groups = {
    for vm in var.vm_configs :
    vm.name => {
      name   = coalesce(vm.resource_group_name, local.resource_group_name)
      create = vm.create_resource_group
    }
  }
}

# Main resource group (for shared resources)
resource "azurerm_resource_group" "main" {
  count    = var.create_resource_group ? 1 : 0
  name     = "${var.project_name}-core-rg"
  location = var.location
}

# VM-specific resource groups
resource "azurerm_resource_group" "vm_groups" {
  for_each = {
    for name, rg in local.vm_resource_groups :
    name => rg if rg.create
  }
  name     = each.value.name
  location = var.location
}

# Automation resource group
resource "azurerm_resource_group" "automation" {
  count    = var.create_automation_resource_group && var.enable_auto_shutdown ? 1 : 0
  name     = local.automation_rg_name
  location = var.location
}

# Network Resources
locals {
  vnet_name = var.create_vnet ? azurerm_virtual_network.main[0].name : var.existing_vnet_name
  subnet_id = var.create_vnet ? azurerm_subnet.main[0].id : data.azurerm_subnet.existing[0].id
}


# Create new VNet and Subnet if specified
resource "azurerm_virtual_network" "main" {
  count               = var.create_vnet ? 1 : 0
  name                = "${var.project_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = local.resource_group_name
}

resource "azurerm_subnet" "main" {
  count                = var.create_vnet ? 1 : 0
  name                 = "${var.project_name}-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.subnet_address_prefix]
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
