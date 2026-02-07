output "namespace_id" {
  description = "Service Bus namespace ID"
  value       = azurerm_servicebus_namespace.main.id
}

output "namespace_name" {
  description = "Service Bus namespace name"
  value       = azurerm_servicebus_namespace.main.name
}

output "namespace_endpoint" {
  description = "Service Bus namespace endpoint"
  value       = azurerm_servicebus_namespace.main.endpoint
}

output "point_accruals_queue_name" {
  description = "Point accruals queue name"
  value       = azurerm_servicebus_queue.point_accruals.name
}

output "point_redemptions_queue_name" {
  description = "Point redemptions queue name"
  value       = azurerm_servicebus_queue.point_redemptions.name
}

output "tier_calculations_queue_name" {
  description = "Tier calculations queue name"
  value       = azurerm_servicebus_queue.tier_calculations.name
}

output "loyalty_events_topic_name" {
  description = "Loyalty events topic name"
  value       = azurerm_servicebus_topic.loyalty_events.name
}

output "identity_principal_id" {
  description = "System-assigned managed identity principal ID"
  value       = azurerm_servicebus_namespace.main.identity[0].principal_id
}
