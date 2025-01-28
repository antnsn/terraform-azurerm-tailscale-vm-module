locals {
  vm_names        = [for vm in var.vm_configs : vm.name]
  resource_groups = [for vm in var.vm_configs : local.vm_resource_groups[vm.name].name]

  # Get current time in UTC with 5-minute buffer
  current_time = timeadd(timestamp(), "5m")

  # Convert startup and shutdown times to UTC
  # For Europe/Oslo (UTC+1), we need to subtract 1 hour from the specified times
  startup_hour_utc = var.startup_hour - 1
  shutdown_hour_utc = var.shutdown_hour - 1
  
  # Format current time components for comparison
  current_hour = tonumber(formatdate("HH", local.current_time))
  current_minute = tonumber(formatdate("mm", local.current_time))
  
  # Calculate if we need tomorrow based on hour and minute comparison in UTC
  use_tomorrow_startup = (
    local.current_hour > local.startup_hour_utc || 
    (local.current_hour == local.startup_hour_utc && local.current_minute >= var.startup_minute)
  )
  
  use_tomorrow_shutdown = (
    local.current_hour > local.shutdown_hour_utc || 
    (local.current_hour == local.shutdown_hour_utc && local.current_minute >= var.shutdown_minute)
  )

  # Get tomorrow's date
  tomorrow = timeadd(local.current_time, "24h")

  # Format the final datetime strings in UTC, ensuring they're always in the future
  startup_datetime = format("%sT%02d:%02d:00Z",
    formatdate("YYYY-MM-DD", local.use_tomorrow_startup ? local.tomorrow : local.current_time),
    local.startup_hour_utc,
    var.startup_minute
  )

  shutdown_datetime = format("%sT%02d:%02d:00Z",
    formatdate("YYYY-MM-DD", local.use_tomorrow_shutdown ? local.tomorrow : local.current_time),
    local.shutdown_hour_utc,
    var.shutdown_minute
  )

  # Ensure both times are valid and in the future
  final_startup_time = timeadd(local.startup_datetime, 
    timecmp(local.startup_datetime, local.current_time) <= 0 ? "24h" : "0h"
  )

  final_shutdown_time = timeadd(local.shutdown_datetime, 
    timecmp(local.shutdown_datetime, local.current_time) <= 0 ? "24h" : "0h"
  )
}

# Create user-assigned managed identity for automation
resource "azurerm_user_assigned_identity" "vm_automation" {
  count               = var.enable_auto_shutdown ? 1 : 0
  name                = "${var.project_name}-automation-identity"
  resource_group_name = local.automation_rg_name
  location            = var.location

  depends_on = [
    azurerm_resource_group.automation
  ]
}

# Create custom role definition for VM start/stop
resource "azurerm_role_definition" "vm_start_stop" {
  count       = var.enable_auto_shutdown ? 1 : 0
  name        = "${var.project_name}-vm-start-stop"
  scope       = data.azurerm_subscription.current.id
  description = "Custom role for starting and stopping VMs"

  permissions {
    actions = [
      # VM operations
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/powerOff/action",
      # Resource group operations
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      # Network operations (needed for VM status)
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

# Assign the custom role to the managed identity for each resource group
resource "azurerm_role_assignment" "vm_automation" {
  for_each = var.enable_auto_shutdown ? merge(
    # Main resource group
    var.create_resource_group ? { "main" = azurerm_resource_group.main[0].id } : {},
    # VM resource groups
    { for name, rg in local.vm_resource_groups : name => (
      rg.create ? 
      azurerm_resource_group.vm_groups[name].id : 
      "/subscriptions/${var.subscription_id}/resourceGroups/${rg.name}"
    )},
    # Automation resource group
    var.create_automation_resource_group ? { "automation" = azurerm_resource_group.automation[0].id } : {}
  ) : {}

  scope              = each.value
  role_definition_id = azurerm_role_definition.vm_start_stop[0].role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.vm_automation[0].principal_id
}

resource "azurerm_automation_account" "vm_automation" {
  count               = var.enable_auto_shutdown ? 1 : 0
  name                = "${var.project_name}-automation"
  location            = var.location
  resource_group_name = local.automation_rg_name
  sku_name            = "Basic"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm_automation[0].id]
  }

  depends_on = [
    azurerm_resource_group.automation,
    azurerm_user_assigned_identity.vm_automation,
    azurerm_role_assignment.vm_automation
  ]
}

# Schedule for starting VMs
resource "azurerm_automation_schedule" "start_schedule" {
  count                   = var.enable_auto_shutdown ? 1 : 0
  name                    = "start-vms-schedule"
  resource_group_name     = local.automation_rg_name
  automation_account_name = azurerm_automation_account.vm_automation[0].name
  frequency               = "Day"
  interval                = 1
  timezone                = var.timezone
  start_time              = local.final_startup_time
  description             = "Start VMs daily at ${var.startup_hour}:${var.startup_minute}"

  depends_on = [
    azurerm_automation_account.vm_automation
  ]
}

# Schedule for stopping VMs
resource "azurerm_automation_schedule" "stop_schedule" {
  count                   = var.enable_auto_shutdown ? 1 : 0
  name                    = "stop-vms-schedule"
  resource_group_name     = local.automation_rg_name
  automation_account_name = azurerm_automation_account.vm_automation[0].name
  frequency               = "Day"
  interval                = 1
  timezone                = var.timezone
  start_time              = local.final_shutdown_time
  description             = "Stop VMs daily at ${var.shutdown_hour}:${var.shutdown_minute}"

  depends_on = [
    azurerm_automation_account.vm_automation
  ]
}

# Runbook for managing VMs
resource "azurerm_automation_runbook" "vm_management" {
  name                    = "vm-management"
  location                = var.location
  resource_group_name     = local.automation_rg_name
  automation_account_name = azurerm_automation_account.vm_automation[0].name
  log_verbose            = true
  log_progress           = true
  description            = "Manage VM start/stop operations"
  runbook_type          = "PowerShell"
  content               = data.local_file.start_stop_script.content

  depends_on = [
    azurerm_automation_account.vm_automation
  ]
}

# Schedule the start job
resource "azurerm_automation_job_schedule" "start_job" {
  resource_group_name     = local.automation_rg_name
  automation_account_name = azurerm_automation_account.vm_automation[0].name
  schedule_name           = azurerm_automation_schedule.start_schedule[0].name
  runbook_name            = azurerm_automation_runbook.vm_management.name

  parameters = {
    action         = "start"
    vmnames        = jsonencode(local.vm_names)
    resourcegroups = jsonencode(local.resource_groups)
    accountid      = azurerm_user_assigned_identity.vm_automation[0].client_id
  }

  depends_on = [
    azurerm_automation_schedule.start_schedule,
    azurerm_automation_runbook.vm_management
  ]
}

# Schedule the stop job
resource "azurerm_automation_job_schedule" "stop_job" {
  resource_group_name     = local.automation_rg_name
  automation_account_name = azurerm_automation_account.vm_automation[0].name
  schedule_name           = azurerm_automation_schedule.stop_schedule[0].name
  runbook_name            = azurerm_automation_runbook.vm_management.name

  parameters = {
    action         = "stop"
    vmnames        = jsonencode(local.vm_names)
    resourcegroups = jsonencode(local.resource_groups)
    accountid      = azurerm_user_assigned_identity.vm_automation[0].client_id
  }

  depends_on = [
    azurerm_automation_schedule.stop_schedule,
    azurerm_automation_runbook.vm_management
  ]
}