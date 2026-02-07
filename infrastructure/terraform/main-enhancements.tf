# ============================================
# Architecture Enhancement Integration
# Add this to your existing main.tf or create as main-enhancements.tf
# ============================================

# ============================================
# Monitoring Stack (REQUIRED)
# ============================================

module "monitoring" {
  source = "./modules/monitoring"

  prefix              = var.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  retention_days      = var.log_retention_days

  # Alert configuration
  critical_alert_emails = var.critical_alert_emails
  warning_alert_emails  = var.warning_alert_emails
  pagerduty_webhook_url = var.pagerduty_webhook_url

  # Thresholds
  error_rate_threshold       = 50
  response_time_threshold_ms = 2000

  # Availability test
  health_check_url = "https://${module.frontdoor.endpoint_hostname}/health"

  tags = var.tags
}

# ============================================
# Azure Front Door with WAF (REQUIRED)
# ============================================

module "frontdoor" {
  source = "./modules/frontdoor"

  prefix              = var.prefix
  resource_group_name = azurerm_resource_group.main.name
  primary_location    = var.location

  # WAF configuration
  waf_mode              = var.environment == "prod" ? "Prevention" : "Detection"
  redemption_rate_limit = 10
  blocked_countries     = var.blocked_countries

  # APIM backends
  apim_primary_hostname = azurerm_api_management.main.gateway_url
  apim_primary_id       = azurerm_api_management.main.id

  # DR (if enabled)
  enable_dr               = var.enable_dr
  secondary_location      = var.secondary_location
  apim_secondary_hostname = var.enable_dr ? azurerm_api_management.secondary[0].gateway_url : ""
  apim_secondary_id       = var.enable_dr ? azurerm_api_management.secondary[0].id : ""

  # Diagnostics
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  tags = var.tags
}

# ============================================
# Service Bus for Async Operations (REQUIRED)
# ============================================

module "servicebus" {
  source = "./modules/servicebus"

  prefix              = var.prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = var.environment == "prod" ? "Premium" : "Standard"
  capacity            = var.environment == "prod" ? 1 : 0

  # Networking
  private_endpoint_subnet_id = azurerm_subnet.private_endpoints.id
  private_dns_zone_id        = azurerm_private_dns_zone.servicebus.id

  # Identity
  aks_workload_identity_principal_id = azurerm_user_assigned_identity.aks_workload.principal_id
  functions_principal_id             = var.enable_functions ? azurerm_linux_function_app.processor[0].identity[0].principal_id : ""

  # Monitoring
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  alert_action_group_id      = module.monitoring.critical_action_group_id

  tags = var.tags
}

# Service Bus private DNS zone
resource "azurerm_private_dns_zone" "servicebus" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  name                  = "${var.prefix}-sb-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# ============================================
# Disaster Recovery (RECOMMENDED for Prod)
# ============================================

module "disaster_recovery" {
  source = "./modules/disaster-recovery"
  count  = var.enable_dr ? 1 : 0

  prefix              = var.prefix
  resource_group_name = azurerm_resource_group.main.name
  primary_location    = var.location
  secondary_location  = var.secondary_location

  # SQL Failover
  primary_sql_server_id = azurerm_mssql_server.main.id
  database_ids          = [for db in azurerm_mssql_database.main : db.id]
  sql_admin_username    = var.sql_admin_username
  sql_admin_password    = var.sql_admin_password
  aad_admin_username    = var.aad_admin_username
  aad_admin_object_id   = var.aad_admin_object_id

  # Networking
  secondary_private_endpoint_subnet_id = azurerm_subnet.secondary_private_endpoints[0].id
  sql_private_dns_zone_id              = azurerm_private_dns_zone.sql.id

  # Cosmos
  enable_cosmos_dr         = true
  cosmos_account_name      = azurerm_cosmosdb_account.main.name
  cosmos_consistency_level = "Session"

  # Traffic Manager
  primary_apim_public_ip_id   = azurerm_public_ip.apim_primary.id
  secondary_apim_public_ip_id = azurerm_public_ip.apim_secondary[0].id
  primary_apim_hostname       = azurerm_api_management.main.gateway_url
  secondary_apim_hostname     = azurerm_api_management.secondary[0].gateway_url
  health_check_host           = "${var.prefix}.azure-api.net"

  tags = var.tags
}

# ============================================
# Azure Policy & Defender (REQUIRED)
# ============================================

module "azure_policy" {
  source = "./modules/azure-policy"

  subscription_id            = data.azurerm_client_config.current.subscription_id
  location                   = var.location
  environment                = var.environment
  assign_at_subscription     = var.environment == "prod"
  resource_group_id          = azurerm_resource_group.main.id
  private_endpoint_effect    = var.environment == "prod" ? "Deny" : "Audit"
  cmk_encryption_effect      = "Audit"
  security_contact_email     = var.security_contact_email
  security_contact_phone     = var.security_contact_phone
}

# ============================================
# Optional: Azure Functions for Message Processing
# ============================================

resource "azurerm_service_plan" "functions" {
  count               = var.enable_functions ? 1 : 0
  name                = "${var.prefix}-func-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "EP1"  # Elastic Premium for VNet integration
  tags                = var.tags
}

resource "azurerm_linux_function_app" "processor" {
  count               = var.enable_functions ? 1 : 0
  name                = "${var.prefix}-func-processor"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.functions[0].id

  storage_account_name       = azurerm_storage_account.functions[0].name
  storage_account_access_key = azurerm_storage_account.functions[0].primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    
    vnet_route_all_enabled = true
    
    application_insights_connection_string = module.monitoring.application_insights_connection_string
  }

  app_settings = {
    "ServiceBusConnection__fullyQualifiedNamespace" = "${module.servicebus.namespace_name}.servicebus.windows.net"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"          = module.monitoring.application_insights_connection_string
  }

  virtual_network_subnet_id = azurerm_subnet.functions[0].id

  tags = var.tags
}

resource "azurerm_storage_account" "functions" {
  count                    = var.enable_functions ? 1 : 0
  name                     = replace("${var.prefix}funcsa", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

# ============================================
# Update AKS for Container Insights
# ============================================

# Add this to your existing AKS resource
# oms_agent {
#   log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
# }

# ============================================
# Store App Insights connection string in Key Vault
# ============================================

resource "azurerm_key_vault_secret" "appinsights_connection_string" {
  name         = "appinsights-connection-string"
  value        = module.monitoring.application_insights_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

# ============================================
# Store Service Bus namespace in App Configuration
# ============================================

resource "azurerm_app_configuration_key" "servicebus_namespace" {
  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "ServiceBus:Namespace"
  value                  = module.servicebus.namespace_name
}

resource "azurerm_app_configuration_key" "servicebus_queues" {
  for_each = {
    "PointAccruals"    = module.servicebus.point_accruals_queue_name
    "PointRedemptions" = module.servicebus.point_redemptions_queue_name
    "TierCalculations" = module.servicebus.tier_calculations_queue_name
  }

  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "ServiceBus:Queues:${each.key}"
  value                  = each.value
}
