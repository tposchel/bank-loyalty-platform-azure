data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.address_space
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = local.aks_sub
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_subnet_cidr]
}

resource "azurerm_container_registry" "acr" {
  name                = local.acr
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = local.la_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "appi" {
  name                = local.ai_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = replace(local.aks, "-", "")

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider { secret_rotation_enabled = true }

  default_node_pool {
    name           = "system"
    node_count     = var.aks_node_count
    vm_size        = var.aks_node_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  azure_active_directory_role_based_access_control {
    managed = true
    admin_group_object_ids = []
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

resource "azurerm_key_vault" "kv" {
  name                        = local.kv
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  tags                        = local.tags
}

resource "azurerm_app_configuration" "appcfg" {
  name                = local.appcfg
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_mssql_server" "sql" {
  name                         = local.sqlsvr
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  tags                         = local.tags
}

resource "azurerm_mssql_database" "platform" { name = "BankLoyalty_Platform" server_id = azurerm_mssql_server.sql.id sku_name = "S0" tags = local.tags }
resource "azurerm_mssql_database" "tenants"  { name = "BankLoyalty_Tenants"  server_id = azurerm_mssql_server.sql.id sku_name = "S0" tags = local.tags }

resource "azurerm_cosmosdb_account" "cosmos" {
  name                = local.cosmos
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  enable_free_tier    = true
  consistency_policy { consistency_level = "Session" }
  geo_location { location = var.location failover_priority = 0 }
  capabilities { name = "EnableServerless" }
  tags = local.tags
}

resource "azurerm_cosmosdb_sql_database" "cosdb" {
  name                = "loyalty"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_redis_cache" "redis" {
  name                = local.redis
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
  minimum_tls_version = "1.2"
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "uami" {
  name                = "${local.base}-wi-uami"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "kv_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.uami.principal_id
}

resource "azurerm_role_assignment" "appcfg_reader" {
  scope                = azurerm_app_configuration.appcfg.id
  role_definition_name = "App Configuration Data Reader"
  principal_id         = azurerm_user_assigned_identity.uami.principal_id
}

resource "kubernetes_namespace" "ns" { metadata { name = var.kube_namespace } }

resource "helm_release" "microplatform" {
  name       = "microplatform"
  namespace  = kubernetes_namespace.ns.metadata[0].name
  chart      = "${path.root}/../../helm/microplatform"
  values = [yamlencode({
    global = {
      imageTag = var.image_tag
      tenantId = data.azurerm_client_config.current.tenant_id
      keyVault = { name = azurerm_key_vault.kv.name }
      workloadIdentity = { enabled = true, clientId = azurerm_user_assigned_identity.uami.client_id }
    }
    image = { registry = var.image_registry }
  })]
  depends_on = [azurerm_user_assigned_identity.uami]
}
