variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "primary_location" {
  description = "Primary Azure region"
  type        = string
}

variable "secondary_location" {
  description = "Secondary Azure region for DR"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "waf_mode" {
  description = "WAF mode: Detection or Prevention"
  type        = string
  default     = "Prevention"
}

variable "waf_redirect_url" {
  description = "URL to redirect blocked requests"
  type        = string
  default     = null
}

variable "redemption_rate_limit" {
  description = "Max redemption requests per minute per IP"
  type        = number
  default     = 10
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "apim_primary_hostname" {
  description = "Primary APIM gateway hostname"
  type        = string
}

variable "apim_primary_id" {
  description = "Primary APIM resource ID"
  type        = string
}

variable "apim_secondary_hostname" {
  description = "Secondary APIM gateway hostname for DR"
  type        = string
  default     = ""
}

variable "apim_secondary_id" {
  description = "Secondary APIM resource ID for DR"
  type        = string
  default     = ""
}

variable "enable_dr" {
  description = "Enable disaster recovery configuration"
  type        = bool
  default     = false
}

variable "custom_domain_ids" {
  description = "List of custom domain resource IDs"
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
}
