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

variable "sku" {
  description = "Service Bus SKU: Basic, Standard, or Premium"
  type        = string
  default     = "Premium"
}

variable "capacity" {
  description = "Messaging units for Premium SKU (1, 2, 4, 8, 16)"
  type        = number
  default     = 1
}

variable "partitions" {
  description = "Number of partitions for Premium SKU"
  type        = number
  default     = 1
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for Service Bus"
  type        = string
}

variable "aks_workload_identity_principal_id" {
  description = "Principal ID of AKS workload identity for RBAC"
  type        = string
}

variable "functions_principal_id" {
  description = "Principal ID of Azure Functions managed identity"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
}

variable "alert_action_group_id" {
  description = "Action group ID for alerts"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
