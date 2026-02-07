# Comprehensive observability stack for loyalty platform
# Application Insights, Log Analytics, alerts, and dashboards

# ============================================
# Log Analytics Workspace
# ============================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days

  # Enable for Container Insights
  internet_ingestion_enabled = true
  internet_query_enabled     = true

  tags = var.tags
}

# ============================================
# Application Insights (workspace-based)
# ============================================

resource "azurerm_application_insights" "main" {
  name                = "${var.prefix}-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  # Disable IP masking for fraud detection (ensure compliance approval)
  disable_ip_masking = var.disable_ip_masking

  # Sampling for high-volume production
  sampling_percentage = var.sampling_percentage

  tags = var.tags
}

# ============================================
# Action Groups for Alerts
# ============================================

resource "azurerm_monitor_action_group" "critical" {
  name                = "${var.prefix}-ag-critical"
  resource_group_name = var.resource_group_name
  short_name          = "Critical"

  dynamic "email_receiver" {
    for_each = var.critical_alert_emails
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email
      use_common_alert_schema = true
    }
  }

  dynamic "sms_receiver" {
    for_each = var.critical_alert_sms
    content {
      name         = sms_receiver.value.name
      country_code = sms_receiver.value.country_code
      phone_number = sms_receiver.value.phone_number
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.pagerduty_webhook_url != "" ? [1] : []
    content {
      name                    = "PagerDuty"
      service_uri             = var.pagerduty_webhook_url
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

resource "azurerm_monitor_action_group" "warning" {
  name                = "${var.prefix}-ag-warning"
  resource_group_name = var.resource_group_name
  short_name          = "Warning"

  dynamic "email_receiver" {
    for_each = var.warning_alert_emails
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

# ============================================
# Smart Detection (Anomaly Detection)
# ============================================

resource "azurerm_application_insights_smart_detection_rule" "failure_anomalies" {
  name                    = "Failure Anomalies"
  application_insights_id = azurerm_application_insights.main.id
  enabled                 = true
  send_emails_to_subscription_owners = false
  additional_email_recipients        = [for e in var.critical_alert_emails : e.email]
}

resource "azurerm_application_insights_smart_detection_rule" "degradation_dependencies" {
  name                    = "Degradation in dependency duration"
  application_insights_id = azurerm_application_insights.main.id
  enabled                 = true
  send_emails_to_subscription_owners = false
  additional_email_recipients        = [for e in var.warning_alert_emails : e.email]
}

# ============================================
# Application-Specific Alerts
# ============================================

# High error rate on loyalty APIs
resource "azurerm_monitor_metric_alert" "high_error_rate" {
  name                = "${var.prefix}-high-error-rate"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Error rate exceeds threshold"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = var.error_rate_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = var.tags
}

# Slow response times
resource "azurerm_monitor_metric_alert" "slow_response" {
  name                = "${var.prefix}-slow-response"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Response time exceeds threshold"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.response_time_threshold_ms
  }

  action {
    action_group_id = azurerm_monitor_action_group.warning.id
  }

  tags = var.tags
}

# Dependency failures (SQL, Cosmos, Redis, Service Bus)
resource "azurerm_monitor_metric_alert" "dependency_failures" {
  name                = "${var.prefix}-dependency-failures"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Backend dependency failures detected"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "dependencies/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = var.tags
}

# ============================================
# Log-based Alerts (KQL)
# ============================================

# Failed point redemptions
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "failed_redemptions" {
  name                = "${var.prefix}-failed-redemptions"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Multiple point redemption failures detected"
  severity            = 1
  enabled             = true

  scopes                   = [azurerm_application_insights.main.id]
  evaluation_frequency     = "PT5M"
  window_duration          = "PT15M"
  target_resource_types    = ["microsoft.insights/components"]

  criteria {
    query = <<-KQL
      requests
      | where name contains "redeem" or name contains "redemption"
      | where success == false
      | summarize FailedCount = count() by bin(timestamp, 5m)
      | where FailedCount > 10
    KQL

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.critical.id]
  }

  tags = var.tags
}

# Unusual point accrual patterns (fraud detection)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "unusual_accruals" {
  name                = "${var.prefix}-unusual-accruals"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Unusual point accrual pattern detected"
  severity            = 2
  enabled             = true

  scopes                   = [azurerm_application_insights.main.id]
  evaluation_frequency     = "PT5M"
  window_duration          = "PT30M"
  target_resource_types    = ["microsoft.insights/components"]

  criteria {
    query = <<-KQL
      customEvents
      | where name == "PointsAccrued"
      | extend CustomerId = tostring(customDimensions.customerId)
      | extend Points = toint(customDimensions.points)
      | summarize 
          TotalPoints = sum(Points), 
          TransactionCount = count() 
        by CustomerId, bin(timestamp, 30m)
      | where TotalPoints > 100000 or TransactionCount > 50
    KQL

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.warning.id]
  }

  tags = var.tags
}

# ============================================
# Availability Tests
# ============================================

resource "azurerm_application_insights_standard_web_test" "api_health" {
  name                    = "${var.prefix}-api-health"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = azurerm_application_insights.main.id
  geo_locations           = var.availability_test_locations
  frequency               = 300  # 5 minutes

  enabled = true

  request {
    url = var.health_check_url
    
    header {
      name  = "x-health-check"
      value = "true"
    }
  }

  validation_rules {
    expected_status_code = 200
    ssl_check_enabled    = true
    ssl_cert_remaining_lifetime = 30
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "availability_alert" {
  name                = "${var.prefix}-availability-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "API availability dropped below threshold"
  severity            = 0  # Critical
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = var.tags
}

# ============================================
# Workbooks (Dashboards)
# ============================================

resource "azurerm_application_insights_workbook" "loyalty_dashboard" {
  name                = "${var.prefix}-loyalty-workbook"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "Loyalty Platform Dashboard"

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "# Loyalty Platform Health Dashboard\n\nReal-time monitoring of loyalty program operations."
        }
        name = "header"
      },
      {
        type = 3
        content = {
          version    = "KqlItem/1.0"
          query      = <<-KQL
            requests
            | where timestamp > ago(1h)
            | summarize 
                Requests = count(),
                FailedRequests = countif(success == false),
                AvgDuration = avg(duration)
              by bin(timestamp, 5m)
            | render timechart
          KQL
          size       = 0
          queryType  = 0
          resourceType = "microsoft.insights/components"
        }
        name = "requests-chart"
      },
      {
        type = 3
        content = {
          version    = "KqlItem/1.0"
          query      = <<-KQL
            customEvents
            | where timestamp > ago(24h)
            | where name in ("PointsAccrued", "PointsRedeemed")
            | extend Points = toint(customDimensions.points)
            | summarize TotalPoints = sum(Points) by name, bin(timestamp, 1h)
            | render columnchart
          KQL
          size       = 0
          queryType  = 0
          resourceType = "microsoft.insights/components"
        }
        name = "points-activity"
      }
    ]
    isLocked = false
  })

  tags = var.tags
}

# ============================================
# Container Insights for AKS
# ============================================

resource "azurerm_log_analytics_solution" "containers" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}
