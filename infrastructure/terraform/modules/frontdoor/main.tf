# Azure Front Door Premium with WAF for global load balancing and DDoS protection
# Recommended for customer-facing financial services

resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "${var.prefix}-afd"
  resource_group_name = var.resource_group_name
  sku_name            = "Premium_AzureFrontDoor"

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "${var.prefix}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  tags = var.tags
}

# WAF Policy - OWASP 3.2 + Bot Protection
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                              = replace("${var.prefix}-waf", "-", "")
  resource_group_name               = var.resource_group_name
  sku_name                          = "Premium_AzureFrontDoor"
  enabled                           = true
  mode                              = var.waf_mode
  redirect_url                      = var.waf_redirect_url
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("Request blocked by WAF policy")

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"

    exclusion {
      match_variable = "QueryStringArgNames"
      operator       = "Equals"
      selector       = "callback"
    }
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  # Rate limiting for loyalty point redemption endpoints
  custom_rule {
    name                           = "RateLimitRedemptions"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = var.redemption_rate_limit
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RequestUri"
      operator           = "Contains"
      negation_condition = false
      match_values       = ["/api/redemptions", "/api/points/redeem"]
    }
  }

  # Geo-blocking if required by regulations
  dynamic "custom_rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlock"
      enabled  = true
      priority = 50
      type     = "MatchRule"
      action   = "Block"

      match_condition {
        match_variable     = "SocketAddr"
        operator           = "GeoMatch"
        negation_condition = false
        match_values       = var.blocked_countries
      }
    }
  }

  tags = var.tags
}

# Origin group pointing to APIM
resource "azurerm_cdn_frontdoor_origin_group" "apim" {
  name                     = "apim-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    path                = "/status-0123456789abcdef"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 30
  }
}

resource "azurerm_cdn_frontdoor_origin" "apim_primary" {
  name                          = "apim-primary"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.apim.id

  enabled                        = true
  host_name                      = var.apim_primary_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = var.apim_primary_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true

  private_link {
    request_message        = "Front Door Private Link"
    target_type            = "sites"
    location               = var.primary_location
    private_link_target_id = var.apim_primary_id
  }
}

# Secondary origin for DR
resource "azurerm_cdn_frontdoor_origin" "apim_secondary" {
  count                         = var.enable_dr ? 1 : 0
  name                          = "apim-secondary"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.apim.id

  enabled                        = true
  host_name                      = var.apim_secondary_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = var.apim_secondary_hostname
  priority                       = 2
  weight                         = 1000
  certificate_name_check_enabled = true

  private_link {
    request_message        = "Front Door Private Link DR"
    target_type            = "sites"
    location               = var.secondary_location
    private_link_target_id = var.apim_secondary_id
  }
}

# Route configuration
resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "main-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.apim.id
  cdn_frontdoor_origin_ids      = var.enable_dr ? [
    azurerm_cdn_frontdoor_origin.apim_primary.id,
    azurerm_cdn_frontdoor_origin.apim_secondary[0].id
  ] : [azurerm_cdn_frontdoor_origin.apim_primary.id]

  supported_protocols    = ["Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true

  cdn_frontdoor_custom_domain_ids = var.custom_domain_ids
}

# Security policy linking WAF to endpoint
resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "waf-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

# Diagnostic settings for Front Door
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  name                       = "frontdoor-diagnostics"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorHealthProbeLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
  }
}
