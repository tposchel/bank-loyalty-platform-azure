# Disaster Recovery Configuration
# Geo-replicated SQL, multi-region Cosmos, Traffic Manager

# ============================================
# SQL Server Geo-Replication
# ============================================

# Secondary SQL Server in DR region
resource "azurerm_mssql_server" "secondary" {
  name                         = "${var.prefix}-sql-secondary"
  resource_group_name          = var.resource_group_name
  location                     = var.secondary_location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"

  azuread_administrator {
    login_username              = var.aad_admin_username
    object_id                   = var.aad_admin_object_id
    azuread_authentication_only = var.aad_only_authentication
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Private endpoint for secondary SQL
resource "azurerm_private_endpoint" "sql_secondary" {
  name                = "${var.prefix}-sql-secondary-pe"
  location            = var.secondary_location
  resource_group_name = var.resource_group_name
  subnet_id           = var.secondary_private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.prefix}-sql-secondary-psc"
    private_connection_resource_id = azurerm_mssql_server.secondary.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.sql_private_dns_zone_id]
  }

  tags = var.tags
}

# Failover group for automatic failover
resource "azurerm_mssql_failover_group" "main" {
  name      = "${var.prefix}-fog"
  server_id = var.primary_sql_server_id
  databases = var.database_ids

  partner_server {
    id = azurerm_mssql_server.secondary.id
  }

  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60
  }

  readonly_endpoint_failover_policy_enabled = true

  tags = var.tags
}

# ============================================
# Cosmos DB Multi-Region (Update existing)
# ============================================

# This should be added to the existing Cosmos module
# Shown here as a reference for the geo_location block

resource "azurerm_cosmosdb_account" "dr_config" {
  count = var.enable_cosmos_dr ? 1 : 0

  name                = var.cosmos_account_name
  location            = var.primary_location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  automatic_failover_enabled = true
  
  # Enable multi-region writes for active-active
  # Or keep false for active-passive with automatic failover
  multiple_write_locations_enabled = var.cosmos_multi_write

  consistency_policy {
    consistency_level       = var.cosmos_consistency_level
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  # Primary region
  geo_location {
    location          = var.primary_location
    failover_priority = 0
    zone_redundant    = true
  }

  # Secondary region (DR)
  geo_location {
    location          = var.secondary_location
    failover_priority = 1
    zone_redundant    = true
  }

  # Optional: Third region for additional redundancy
  dynamic "geo_location" {
    for_each = var.tertiary_location != "" ? [1] : []
    content {
      location          = var.tertiary_location
      failover_priority = 2
      zone_redundant    = false
    }
  }

  backup {
    type                = "Continuous"
    tier                = "Continuous7Days"
  }

  tags = var.tags
}

# ============================================
# Redis Geo-Replication (Premium tier required)
# ============================================

resource "azurerm_redis_cache" "secondary" {
  count               = var.enable_redis_dr ? 1 : 0
  name                = "${var.prefix}-redis-secondary"
  location            = var.secondary_location
  resource_group_name = var.resource_group_name
  capacity            = var.redis_capacity
  family              = "P"
  sku_name            = "Premium"
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "volatile-lru"
  }

  tags = var.tags
}

resource "azurerm_redis_linked_server" "geo_replication" {
  count                       = var.enable_redis_dr ? 1 : 0
  target_redis_cache_name     = var.primary_redis_cache_name
  resource_group_name         = var.resource_group_name
  linked_redis_cache_id       = azurerm_redis_cache.secondary[0].id
  linked_redis_cache_location = var.secondary_location
  server_role                 = "Secondary"
}

# ============================================
# Traffic Manager for Global Load Balancing
# ============================================

resource "azurerm_traffic_manager_profile" "main" {
  name                   = "${var.prefix}-tm"
  resource_group_name    = var.resource_group_name
  traffic_routing_method = var.traffic_routing_method

  dns_config {
    relative_name = var.prefix
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/health"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
    expected_status_code_ranges  = ["200-299"]

    custom_header {
      name  = "host"
      value = var.health_check_host
    }
  }

  tags = var.tags
}

# Primary endpoint
resource "azurerm_traffic_manager_azure_endpoint" "primary" {
  name               = "primary"
  profile_id         = azurerm_traffic_manager_profile.main.id
  priority           = 1
  weight             = 100
  target_resource_id = var.primary_apim_public_ip_id
  enabled            = true

  custom_header {
    name  = "host"
    value = var.primary_apim_hostname
  }
}

# Secondary endpoint (DR)
resource "azurerm_traffic_manager_azure_endpoint" "secondary" {
  name               = "secondary"
  profile_id         = azurerm_traffic_manager_profile.main.id
  priority           = 2
  weight             = 100
  target_resource_id = var.secondary_apim_public_ip_id
  enabled            = true

  custom_header {
    name  = "host"
    value = var.secondary_apim_hostname
  }
}

# ============================================
# AKS DR Guidance (as data/locals)
# ============================================

# AKS DR is typically handled via GitOps (Flux/ArgoCD)
# Deploy same manifests to secondary cluster
# Use Azure Backup for AKS for stateful workloads

locals {
  aks_dr_guidance = {
    strategy = "Active-Passive with GitOps"
    steps = [
      "1. Deploy secondary AKS cluster in DR region",
      "2. Configure GitOps (Flux/ArgoCD) to sync both clusters",
      "3. Use Azure Front Door or Traffic Manager for routing",
      "4. Use Velero for PV backup/restore if stateful",
      "5. Test failover quarterly"
    ]
    rpo_target = "< 1 hour"
    rto_target = "< 4 hours"
  }
}

# Output DR configuration for documentation
output "dr_guidance" {
  description = "AKS disaster recovery guidance"
  value       = local.aks_dr_guidance
}

# ============================================
# Azure Site Recovery Vault (for VM-based workloads)
# ============================================

resource "azurerm_recovery_services_vault" "main" {
  count               = var.enable_asr ? 1 : 0
  name                = "${var.prefix}-rsv"
  location            = var.secondary_location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  soft_delete_enabled = true

  tags = var.tags
}
