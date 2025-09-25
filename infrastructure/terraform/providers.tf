terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm   = { source = "hashicorp/azurerm", version = "~> 3.114" }
    azuread   = { source = "hashicorp/azuread", version = "~> 2.49" }
    kubernetes= { source = "hashicorp/kubernetes", version = "~> 2.33" }
    helm      = { source = "hashicorp/helm",       version = "~> 2.12" }
    external  = { source = "hashicorp/external",   version = "~> 2.3" }
    random    = { source = "hashicorp/random",     version = "~> 3.6" }
    null      = { source = "hashicorp/null",       version = "~> 3.2" }
  }
}
provider "azurerm" { features {} }
provider "azuread" { alias = "b2c" tenant_id = var.b2c_tenant_id }
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}
