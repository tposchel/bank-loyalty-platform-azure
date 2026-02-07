output "policy_set_id" {
  description = "Loyalty platform policy set definition ID"
  value       = azurerm_policy_set_definition.loyalty_platform_baseline.id
}

output "policy_assignment_id" {
  description = "Policy assignment ID"
  value       = var.assign_at_subscription ? azurerm_subscription_policy_assignment.loyalty_baseline[0].id : azurerm_resource_group_policy_assignment.loyalty_baseline_rg[0].id
}

output "policy_assignment_identity_principal_id" {
  description = "Policy assignment managed identity principal ID"
  value       = var.assign_at_subscription ? azurerm_subscription_policy_assignment.loyalty_baseline[0].identity[0].principal_id : azurerm_resource_group_policy_assignment.loyalty_baseline_rg[0].identity[0].principal_id
}
