# Create Network Interface for each VM
resource "azurerm_network_interface" "main" {
  for_each            = { for vm in var.vm_configs : vm.name => vm }
  name                = "${each.value.name}-nic"
  location            = var.location
  resource_group_name = local.vm_resource_groups[each.key].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_resource_group.vm_groups ]
}

# Create VMs
resource "azurerm_linux_virtual_machine" "main" {
  for_each            = { for vm in var.vm_configs : vm.name => vm }
  name                = each.value.name
  location            = var.location
  resource_group_name = local.vm_resource_groups[each.key].name
  size                = each.value.size
  admin_username      = each.value.admin_username

  network_interface_ids = [
    azurerm_network_interface.main[each.key].id
  ]

  dynamic "admin_ssh_key" {
    for_each = each.value.use_ssh_key ? [1] : []
    content {
      username   = each.value.admin_username
      public_key = file(each.value.ssh_key_path)
    }
  }

  admin_password                  = each.value.use_ssh_key ? null : each.value.admin_password
  disable_password_authentication = each.value.use_ssh_key

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = each.value.image_publisher
    offer     = each.value.image_offer
    sku       = each.value.image_sku
    version   = each.value.image_version
  }
  depends_on = [ azurerm_resource_group.vm_groups ]
}

# Create new Key Vault or use existing one
locals {
  key_vault_name = var.create_key_vault ? azurerm_key_vault.main[0].name : var.existing_key_vault_name
  key_vault_rg   = var.create_key_vault ? local.resource_group_name : var.existing_key_vault_rg
}

# Data source for existing Key Vault
data "azurerm_key_vault" "existing" {
  count               = var.enable_tailscale && !var.create_key_vault ? 1 : 0
  name                = var.existing_key_vault_name
  resource_group_name = var.existing_key_vault_rg
}

# Create Key Vault for storing Tailscale auth key
resource "azurerm_key_vault" "main" {
  count                       = var.enable_tailscale && var.create_key_vault ? 1 : 0
  name                       = "${var.project_name}-kv"
  location                   = var.location
  resource_group_name        = local.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                  = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge"
    ]
  }
  depends_on = [ azurerm_resource_group.main ]  
}

# Add access policy to existing Key Vault if using one
resource "azurerm_key_vault_access_policy" "main" {
  count        = var.enable_tailscale && !var.create_key_vault ? 1 : 0
  key_vault_id = data.azurerm_key_vault.existing[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge"
  ]
}

# Store Tailscale auth key in Key Vault
resource "azurerm_key_vault_secret" "tailscale_auth_key" {
  count        = var.enable_tailscale ? 1 : 0
  name         = "tailscale-auth-key"
  value        = var.tailscale_auth_key
  key_vault_id = var.create_key_vault ? azurerm_key_vault.main[0].id : data.azurerm_key_vault.existing[0].id

  depends_on = [
    azurerm_key_vault.main,
    azurerm_key_vault_access_policy.main
  ]
}

# Create VM extension for Tailscale setup
resource "azurerm_virtual_machine_extension" "tailscale" {
  for_each             = var.enable_tailscale ? { for vm in var.vm_configs : vm.name => vm } : {}
  name                 = "tailscale"
  virtual_machine_id   = azurerm_linux_virtual_machine.main[each.key].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    commandToExecute = <<-EOF
      #!/bin/bash
      curl -fsSL https://tailscale.com/install.sh | sh
      tailscale up --authkey=${var.tailscale_auth_key} --hostname=${each.key}
    EOF
  })

  tags = {
    environment = "production"
  }

  lifecycle {
    ignore_changes = [
      protected_settings,
    ]
  }
}