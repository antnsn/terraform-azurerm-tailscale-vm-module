terraform {
  # Configure your backend as needed
  # backend "remote" {
  #   organization = "your-org"
  #   workspaces {
  #     name = "your-workspace"
  #   }
  # }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "azure_vm_infrastructure" {
  source = "../"

  # General Settings
  project_name    = "example-project"
  location        = "westeurope"  # Change to your preferred region
  subscription_id = var.subscription_id

  # Resource Group Settings
  create_resource_group = true
  # existing_resource_group_name = "existing-rg"  # Uncomment to use existing resource group

  # Network Settings
  create_vnet           = true
  vnet_address_space    = "10.0.0.0/16"
  subnet_address_prefix = "10.0.1.0/24"
  # Uncomment below to use existing network
  # create_vnet = false
  # existing_vnet_name = "existing-vnet"
  # existing_subnet_name = "existing-subnet"

  # VM Configurations
  vm_configs = [
    # Example 1: Linux VM with SSH Key
    {
      name                 = "linux-vm1"
      resource_group_name  = "vm-rg"
      create_resource_group = true
      size                 = "Standard_B2s"  # Cost-effective size for dev/test
      admin_username       = "adminuser"
      use_ssh_key         = true
      ssh_key_path        = "~/.ssh/id_rsa.pub"
      admin_password      = null
      image_publisher     = "Canonical"
      image_offer         = "0001-com-ubuntu-server-jammy"
      image_sku          = "22_04-lts-gen2"
      image_version      = "latest"
    },
    # Example 2: Linux VM in same resource group
    {
      name                 = "linux-vm2"
      resource_group_name  = "vm-rg"  # Same RG as vm1
      create_resource_group = false    # RG already created by vm1
      size                 = "Standard_B2s"
      admin_username       = "adminuser"
      use_ssh_key         = true
      ssh_key_path        = "~/.ssh/id_rsa.pub"
      admin_password      = null
      image_publisher     = "Canonical"
      image_offer         = "0001-com-ubuntu-server-jammy"
      image_sku          = "22_04-lts-gen2"
      image_version      = "latest"
    },
        # Example 3: Linux VM using password
    {
      name                 = "linux-vm3"
      resource_group_name  = "vm3-rg"  
      create_resource_group = true
      size                 = "Standard_B2s"
      admin_username       = "adminuser"
      use_ssh_key         = false
      ssh_key_path        = null
      admin_password      = "Password123!"
      image_publisher     = "Canonical"
      image_offer         = "0001-com-ubuntu-server-jammy"
      image_sku          = "22_04-lts-gen2"
      image_version      = "latest"
    }
  ]

  # Automation Settings
  enable_auto_shutdown = true
  timezone            = "UTC"  # Change to your timezone
  startup_hour        = 8
  startup_minute      = 0
  shutdown_hour       = 18
  shutdown_minute     = 0

  # Tailscale Settings (Optional)
  enable_tailscale    = false  # Set to true if using Tailscale
  # tailscale_auth_key  = var.tailscale_auth_key  # Uncomment when enable_tailscale = true

  # Key Vault Settings (Optional)
  create_key_vault = true
  # Uncomment below to use existing Key Vault
  # create_key_vault = false
  # existing_key_vault_name = "existing-kv"
  # existing_key_vault_rg = "existing-kv-rg"
}