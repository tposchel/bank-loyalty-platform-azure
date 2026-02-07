output "profile_id" {
  description = "Front Door profile ID"
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "endpoint_hostname" {
  description = "Front Door endpoint hostname"
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "endpoint_id" {
  description = "Front Door endpoint ID"
  value       = azurerm_cdn_frontdoor_endpoint.main.id
}

output "waf_policy_id" {
  description = "WAF policy ID"
  value       = azurerm_cdn_frontdoor_firewall_policy.main.id
}
