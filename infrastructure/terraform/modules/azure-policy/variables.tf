variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID for RG-level assignment"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for managed identity"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "assign_at_subscription" {
  description = "Assign policies at subscription level (vs resource group)"
  type        = bool
  default     = true
}

variable "private_endpoint_effect" {
  description = "Effect for private endpoint policy: Audit, Deny, or Disabled"
  type        = string
  default     = "Audit"
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.private_endpoint_effect)
    error_message = "Effect must be Audit, Deny, or Disabled."
  }
}

variable "cmk_encryption_effect" {
  description = "Effect for CMK encryption policy: Audit, Deny, or Disabled"
  type        = string
  default     = "Audit"
}

variable "security_contact_email" {
  description = "Security team email for Defender alerts"
  type        = string
}

variable "security_contact_phone" {
  description = "Security team phone for critical alerts"
  type        = string
  default     = ""
}
