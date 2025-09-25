output "resource_group"     { value = azurerm_resource_group.rg.name }
output "acr_login_server"   { value = azurerm_container_registry.acr.login_server }
output "aks_name"           { value = azurerm_kubernetes_cluster.aks.name }
output "aks_kubeconfig"     { value = azurerm_kubernetes_cluster.aks.kube_config_raw sensitive = true }
output "key_vault_name"     { value = azurerm_key_vault.kv.name }
output "sql_server_fqdn"    { value = azurerm_mssql_server.sql.fully_qualified_domain_name }
output "cosmos_endpoint"    { value = azurerm_cosmosdb_account.cosmos.endpoint }
output "redis_hostname"     { value = azurerm_redis_cache.redis.hostname }
output "appconfig_endpoint" { value = azurerm_app_configuration.appcfg.endpoint }
