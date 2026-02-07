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
}

variable "tertiary_location" {
  description = "Optional third region for Cosmos"
  type        = string
  default     = ""
}

# SQL Server Variables
variable "primary_sql_server_id" {
  description = "Primary SQL Server resource ID"
  type        = string
}

variable "database_ids" {
  description = "List of database IDs to replicate"
  type        = list(string)
}

variable "sql_admin_username" {
  description = "SQL admin username"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL admin password"
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

variable "aad_only_authentication" {
  description = "Enable AAD-only authentication"
  type        = bool
  default     = true
}

variable "secondary_private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints in secondary region"
  type        = string
}

variable "sql_private_dns_zone_id" {
  description = "Private DNS zone ID for SQL"
  type        = string
}

# Cosmos Variables
variable "enable_cosmos_dr" {
  description = "Enable Cosmos DB multi-region"
  type        = bool
  default     = true
}

variable "cosmos_account_name" {
  description = "Existing Cosmos account name"
  type        = string
  default     = ""
}

variable "cosmos_multi_write" {
  description = "Enable multi-region writes (active-active)"
  type        = bool
  default     = false
}

variable "cosmos_consistency_level" {
  description = "Cosmos DB consistency level"
  type        = string
  default     = "Session"
}

# Redis Variables
variable "enable_redis_dr" {
  description = "Enable Redis geo-replication"
  type        = bool
  default     = false
}

variable "primary_redis_cache_name" {
  description = "Primary Redis cache name"
  type        = string
  default     = ""
}

variable "redis_capacity" {
  description = "Redis cache capacity"
  type        = number
  default     = 1
}

# Traffic Manager Variables
variable "traffic_routing_method" {
  description = "Traffic routing method: Priority, Weighted, Performance, Geographic"
  type        = string
  default     = "Priority"
}

variable "primary_apim_public_ip_id" {
  description = "Primary APIM public IP resource ID"
  type        = string
}

variable "secondary_apim_public_ip_id" {
  description = "Secondary APIM public IP resource ID"
  type        = string
}

variable "primary_apim_hostname" {
  description = "Primary APIM hostname"
  type        = string
}

variable "secondary_apim_hostname" {
  description = "Secondary APIM hostname"
  type        = string
}

variable "health_check_host" {
  description = "Host header for health checks"
  type        = string
}

# Azure Site Recovery
variable "enable_asr" {
  description = "Enable Azure Site Recovery vault"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
