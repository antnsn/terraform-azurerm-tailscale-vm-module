output "resource_group_name" {
  description = "The name of the main resource group"
  value       = var.create_resource_group ? azurerm_resource_group.main[0].name : var.existing_resource_group_name
}

output "vm_private_ips" {
  description = "Map of VM names to their private IP addresses"
  value = {
    for vm_name, nic in azurerm_network_interface.main : vm_name => nic.private_ip_address
  }
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = var.create_vnet ? azurerm_virtual_network.main[0].name : var.existing_vnet_name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = local.subnet_id
}

output "vm_resource_groups" {
  description = "Map of VM names to their resource group names"
  value       = local.vm_resource_groups
}

output "automation_resource_group_name" {
  description = "The name of the automation resource group"
  value       = var.enable_auto_shutdown ? local.automation_rg_name : null
}

output "vm_names" {
  description = "List of created VM names"
  value       = local.vm_names
}

output "automation_account_name" {
  description = "The name of the automation account if enabled"
  value       = var.enable_auto_shutdown ? azurerm_automation_account.vm_automation[0].name : null
} 