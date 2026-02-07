# ============================================
# Enhancement Variables
# Add these to your existing variables.tf
# ============================================

# Monitoring
variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 90
}

variable "critical_alert_emails" {
  description = "Email recipients for critical alerts"
  type = list(object({
    name  = string
    email = string
  }))
  default = []
}

variable "warning_alert_emails" {
  description = "Email recipients for warning alerts"
  type = list(object({
    name  = string
    email = string
  }))
  default = []
}

variable "pagerduty_webhook_url" {
  description = "PagerDuty webhook for critical alerts"
  type        = string
  default     = ""
  sensitive   = true
}

# Front Door
variable "blocked_countries" {
  description = "Countries to block at WAF (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

# Disaster Recovery
variable "enable_dr" {
  description = "Enable disaster recovery configuration"
  type        = bool
  default     = false
}

variable "secondary_location" {
  description = "Secondary Azure region for DR"
  type        = string
  default     = "westus2"
}

# SQL (for DR)
variable "sql_admin_username" {
  description = "SQL Server admin username"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true
}

variable "aad_admin_username" {
  description = "AAD admin username for SQL"
  type        = string
}

variable "aad_admin_object_id" {
  description = "AAD admin object ID for SQL"
  type        = string
}

# Azure Functions
variable "enable_functions" {
  description = "Enable Azure Functions for message processing"
  type        = bool
  default     = false
}

# Security
variable "security_contact_email" {
  description = "Security team email for Defender alerts"
  type        = string
}

variable "security_contact_phone" {
  description = "Security team phone for critical alerts"
  type        = string
  default     = ""
}
