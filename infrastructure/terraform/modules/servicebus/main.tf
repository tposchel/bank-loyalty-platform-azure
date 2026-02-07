# Azure Service Bus for async loyalty operations
# Decouples point accruals, tier calculations, and notifications

resource "azurerm_servicebus_namespace" "main" {
  name                          = "${var.prefix}-sb"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = var.sku == "Premium" ? var.capacity : 0
  premium_messaging_partitions  = var.sku == "Premium" ? var.partitions : 0
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  local_auth_enabled            = false  # Force AAD auth only

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Private endpoint for Service Bus
resource "azurerm_private_endpoint" "servicebus" {
  name                = "${var.prefix}-sb-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.prefix}-sb-psc"
    private_connection_resource_id = azurerm_servicebus_namespace.main.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

# ============================================
# QUEUES - For point-to-point messaging
# ============================================

# Point accrual queue - high volume, needs partitioning
resource "azurerm_servicebus_queue" "point_accruals" {
  name         = "point-accruals"
  namespace_id = azurerm_servicebus_namespace.main.id

  enable_partitioning                     = var.sku != "Premium"
  max_delivery_count                      = 10
  dead_lettering_on_message_expiration    = true
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
  lock_duration                           = "PT5M"
  max_size_in_megabytes                   = 5120
  default_message_ttl                     = "P14D"
}

# Point redemption queue - critical, needs sessions for ordering
resource "azurerm_servicebus_queue" "point_redemptions" {
  name         = "point-redemptions"
  namespace_id = azurerm_servicebus_namespace.main.id

  requires_session                        = true  # Ensures FIFO per customer
  max_delivery_count                      = 5
  dead_lettering_on_message_expiration    = true
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
  lock_duration                           = "PT2M"
  max_size_in_megabytes                   = 5120
  default_message_ttl                     = "P7D"
}

# Tier calculation queue - batch processing
resource "azurerm_servicebus_queue" "tier_calculations" {
  name         = "tier-calculations"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count                   = 3
  dead_lettering_on_message_expiration = true
  lock_duration                        = "PT5M"
  max_size_in_megabytes                = 5120
  default_message_ttl                  = "P1D"
}

# Dead letter processing queue (for reprocessing failed messages)
resource "azurerm_servicebus_queue" "dlq_reprocess" {
  name         = "dlq-reprocess"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count                   = 1
  dead_lettering_on_message_expiration = true
  lock_duration                        = "PT5M"
  max_size_in_megabytes                = 5120
  default_message_ttl                  = "P30D"
}

# ============================================
# TOPICS - For pub/sub messaging
# ============================================

# Loyalty events topic - pub/sub for multiple consumers
resource "azurerm_servicebus_topic" "loyalty_events" {
  name         = "loyalty-events"
  namespace_id = azurerm_servicebus_namespace.main.id

  enable_partitioning                     = var.sku != "Premium"
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
  max_size_in_megabytes                   = 5120
  default_message_ttl                     = "P7D"
  support_ordering                        = true
}

# Subscription: Notification service
resource "azurerm_servicebus_subscription" "notifications" {
  name               = "notifications"
  topic_id           = azurerm_servicebus_topic.loyalty_events.id
  max_delivery_count = 5
  lock_duration      = "PT1M"

  dead_lettering_on_message_expiration          = true
  dead_lettering_on_filter_evaluation_exception = true
}

resource "azurerm_servicebus_subscription_rule" "notifications_filter" {
  name            = "notification-events"
  subscription_id = azurerm_servicebus_subscription.notifications.id
  filter_type     = "SqlFilter"
  sql_filter      = "EventType IN ('PointsEarned', 'PointsRedeemed', 'TierChanged', 'RewardExpiring')"
}

# Subscription: Analytics service
resource "azurerm_servicebus_subscription" "analytics" {
  name               = "analytics"
  topic_id           = azurerm_servicebus_topic.loyalty_events.id
  max_delivery_count = 3
  lock_duration      = "PT2M"

  dead_lettering_on_message_expiration = true
}

# Analytics gets all events (no filter)
resource "azurerm_servicebus_subscription_rule" "analytics_all" {
  name            = "all-events"
  subscription_id = azurerm_servicebus_subscription.analytics.id
  filter_type     = "SqlFilter"
  sql_filter      = "1=1"
}

# Subscription: Fraud detection
resource "azurerm_servicebus_subscription" "fraud_detection" {
  name               = "fraud-detection"
  topic_id           = azurerm_servicebus_topic.loyalty_events.id
  max_delivery_count = 3
  lock_duration      = "PT30S"  # Fast processing

  dead_lettering_on_message_expiration = true
}

resource "azurerm_servicebus_subscription_rule" "fraud_filter" {
  name            = "high-value-transactions"
  subscription_id = azurerm_servicebus_subscription.fraud_detection.id
  filter_type     = "SqlFilter"
  sql_filter      = "PointValue > 10000 OR EventType = 'PointsRedeemed'"
}

# ============================================
# RBAC - Workload identity access
# ============================================

# Role assignment for AKS workload identity
resource "azurerm_role_assignment" "aks_servicebus_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = var.aks_workload_identity_principal_id
}

resource "azurerm_role_assignment" "aks_servicebus_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = var.aks_workload_identity_principal_id
}

# Role for Azure Functions (if using for processing)
resource "azurerm_role_assignment" "functions_servicebus" {
  count                = var.functions_principal_id != "" ? 1 : 0
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = var.functions_principal_id
}

# ============================================
# Diagnostics
# ============================================

resource "azurerm_monitor_diagnostic_setting" "servicebus" {
  name                       = "servicebus-diagnostics"
  target_resource_id         = azurerm_servicebus_namespace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "OperationalLogs"
  }

  enabled_log {
    category = "VNetAndIPFilteringLogs"
  }

  enabled_log {
    category = "RuntimeAuditLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

# ============================================
# Alerts
# ============================================

resource "azurerm_monitor_metric_alert" "dlq_messages" {
  name                = "${var.prefix}-sb-dlq-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_servicebus_namespace.main.id]
  description         = "Alert when dead letter queue has messages"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "DeadletteredMessages"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = var.alert_action_group_id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "throttled_requests" {
  name                = "${var.prefix}-sb-throttle-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_servicebus_namespace.main.id]
  description         = "Alert when requests are being throttled"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "ThrottledRequests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = var.alert_action_group_id
  }

  tags = var.tags
}
