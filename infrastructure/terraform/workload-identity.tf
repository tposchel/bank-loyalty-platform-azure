variable "kube_namespace" { type = string }
data "external" "service_accounts" {
  program = ["bash", "${path.module}/scripts/list-sas.sh", var.kube_namespace]
}
resource "azurerm_federated_identity_credential" "fic" {
  for_each     = { for sa in try(jsondecode(data.external.service_accounts.result.workloads_json), []) : sa => sa }
  name         = "${var.prefix}-${var.environment}-${each.value}-fic"
  resource_id  = azurerm_user_assigned_identity.uami.id
  issuer       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  audience     = ["api://AzureADTokenExchange"]
  subject      = "system:serviceaccount:${var.kube_namespace}:${each.value}"
}
