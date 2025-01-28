variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
}

variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}