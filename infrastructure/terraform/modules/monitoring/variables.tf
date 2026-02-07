variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 90
}

variable "sampling_percentage" {
  description = "Application Insights sampling percentage (100 = no sampling)"
  type        = number
  default     = 100
}

variable "disable_ip_masking" {
  description = "Disable IP masking for fraud detection (requires compliance approval)"
  type        = bool
  default     = false
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

variable "critical_alert_sms" {
  description = "SMS recipients for critical alerts"
  type = list(object({
    name         = string
    country_code = string
    phone_number = string
  }))
  default = []
}

variable "pagerduty_webhook_url" {
  description = "PagerDuty webhook URL for critical alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "error_rate_threshold" {
  description = "Number of failed requests to trigger alert"
  type        = number
  default     = 50
}

variable "response_time_threshold_ms" {
  description = "Response time threshold in milliseconds"
  type        = number
  default     = 2000
}

variable "availability_test_locations" {
  description = "Geo locations for availability tests"
  type        = list(string)
  default     = ["us-va-ash-azr", "us-il-ch1-azr", "emea-gb-db3-azr", "emea-nl-ams-azr", "apac-sg-sin-azr"]
}

variable "health_check_url" {
  description = "URL for availability health check"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
