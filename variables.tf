# General Settings
variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Norway East"
}

# Resource Group Settings
variable "create_resource_group" {
  description = "Whether to create a new resource group or use existing"
  type        = bool
  default     = true
}

variable "existing_resource_group_name" {
  description = "Name of existing resource group if not creating new"
  type        = string
  default     = ""
}

# Network Settings
variable "create_vnet" {
  description = "Whether to create a new VNet or use existing"
  type        = bool
  default     = true
}

variable "existing_vnet_name" {
  description = "Name of existing VNet if not creating new"
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of existing subnet if not creating new"
  type        = string
  default     = ""
}

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# VM Settings
variable "vm_configs" {
  description = "Configuration for VMs to create"
  type = list(object({
    name                  = string
    size                  = string
    admin_username        = string
    use_ssh_key           = bool
    ssh_key_path          = optional(string)
    admin_password        = optional(string)
    image_publisher       = string
    image_offer           = string
    image_sku             = string
    image_version         = string
    resource_group_name   = optional(string)      # Optional: if not provided, will use the main resource group
    create_resource_group = optional(bool, false) # Whether to create a new RG for this VM
  }))

  validation {
    condition = alltrue([
      for vm in var.vm_configs :
      (vm.use_ssh_key && vm.ssh_key_path != null) ||
      (!vm.use_ssh_key && vm.admin_password != null)
    ])
    error_message = "When use_ssh_key is true, ssh_key_path must be provided. When use_ssh_key is false, admin_password must be provided."
  }
}

# Automation Settings
variable "enable_auto_shutdown" {
  description = "Enable automatic shutdown/startup schedule"
  type        = bool
  default     = false
}

# Existing variables for automation if enabled
variable "timezone" {
  description = "Timezone for VM scheduling"
  type        = string
  default     = "Europe/Oslo"
}

variable "startup_hour" {
  description = "Hour to start VMs (24h format)"
  type        = number
  default     = 8
}

variable "startup_minute" {
  description = "Minute to start VMs"
  type        = number
  default     = 0
}

variable "shutdown_hour" {
  description = "Hour to stop VMs (24h format)"
  type        = number
  default     = 17
}

variable "shutdown_minute" {
  description = "Minute to stop VMs"
  type        = number
  default     = 0
}

# Optional Tailscale Settings
variable "enable_tailscale" {
  description = "Enable Tailscale VPN on VMs"
  type        = bool
  default     = false
}

variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  default     = ""
  sensitive   = true
}

# Key Vault Settings
variable "create_key_vault" {
  description = "Create a new Key Vault or use existing one"
  type        = bool
  default     = true
}

variable "existing_key_vault_name" {
  description = "Name of existing Key Vault to use if create_key_vault is false"
  type        = string
  default     = ""
}

variable "existing_key_vault_rg" {
  description = "Resource group of existing Key Vault if create_key_vault is false"
  type        = string
  default     = ""
}

# Automation Resource Group Settings
variable "automation_resource_group_name" {
  description = "Name for the automation resource group"
  type        = string
  default     = null # If null, will use project_name-automation-rg
}

variable "create_automation_resource_group" {
  description = "Whether to create a new resource group for automation resources"
  type        = bool
  default     = true
}

variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
}
