# Azure Infrastructure

This project manages Azure infrastructure using Terraform, including VM management and automated start/stop schedules.

## Overview
- Multiple VMs with automated start/stop schedules
- Tailscale VPN integration with secure key management
- Azure Key Vault integration for secrets
- Azure Automation for VM management
- Terraform-managed infrastructure

## Infrastructure Components
- Azure Virtual Machines
- Azure Automation Account
- Azure Key Vault
- PowerShell Runbooks
- Virtual Network and Subnet
- Network Interfaces

## Prerequisites
- Azure subscription
- Terraform installed
- Azure CLI installed and authenticated
- Tailscale account (if using Tailscale VPN)
- Existing Key Vault (optional)

## Configuration

### Required Variables
Create a `terraform.tfvars` file with the following variables:

```hcl
# Azure Subscription ID
subscription_id = "your-subscription-id"

# Tailscale Settings
enable_tailscale = true
tailscale_auth_key = "your-tailscale-auth-key"

# Key Vault Settings (Option 1: Create new Key Vault)
create_key_vault = true

# Key Vault Settings (Option 2: Use existing Key Vault)
# create_key_vault = false
# existing_key_vault_name = "my-existing-kv"
# existing_key_vault_rg = "my-existing-rg"

# Optional: Override default schedule times (24h format)
startup_hour = 8
startup_minute = 0
shutdown_hour = 17
shutdown_minute = 0
```

### Variable Descriptions
- `subscription_id`: Your Azure subscription ID
- `enable_tailscale`: Enable/disable Tailscale VPN integration
- `tailscale_auth_key`: Authentication key for Tailscale VPN integration
- `create_key_vault`: Whether to create a new Key Vault or use existing
- `existing_key_vault_name`: Name of existing Key Vault (if using one)
- `existing_key_vault_rg`: Resource group of existing Key Vault
- `startup_hour`, `startup_minute`: Time to start VMs daily (default: 08:00)
- `shutdown_hour`, `shutdown_minute`: Time to stop VMs daily (default: 17:00)

## Key Features

### Tailscale Integration
- Secure VPN connectivity using Tailscale
- Auth key stored securely in Azure Key Vault
- VM extension-based setup (no VM recreation on key updates)
- Automatic hostname configuration

### Key Vault Integration
- Option to create new or use existing Key Vault
- Secure storage for Tailscale auth keys
- Automatic access policy configuration
- Support for key rotation without VM replacement

### Automation Features
- **Dynamic VM Discovery**: Automatically detects all VMs in the resource group
- **Smart Scheduling**: 
  - Start Time: 08:00 (Europe/Oslo)
  - Stop Time: 17:00 (Europe/Oslo)
  - Automatically adjusts schedule dates based on current time
  - If current time is past the schedule time, sets for next day
- **Managed Identity**: Uses system-assigned managed identity for secure authentication

## Usage

1. Clone the repository
2. Create `terraform.tfvars` with your values
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Review the planned changes:
   ```bash
   terraform plan
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

## File Structure
- `main.tf`: Main infrastructure configuration
- `vm.tf`: VM and Key Vault configuration
- `automation.tf`: VM automation schedules and runbooks
- `variables.tf`: Variable definitions
- `terraform.tfvars`: Variable values (not in repo)

## Notes
- VMs are automatically discovered in the specified resource group
- Automation uses Azure Automation Account with PowerShell runbooks
- Times are set in Europe/Oslo timezone
- Schedule dates automatically adjust based on current time
- Tailscale auth key can be updated without VM recreation
- Make sure your Azure subscription has necessary permissions

## Security
- VMs are accessible via Tailscale VPN
- Secrets stored securely in Azure Key Vault
- No public IP addresses exposed
- Automated shutdown ensures cost optimization
- Uses managed identity for secure automation
