resource "azurerm_key_vault_secret" "sql_conn" {
  name         = "sql-connection-string"
  key_vault_id = azurerm_key_vault.kv.id
  value        = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.tenants.name};Persist Security Info=False;User ID=${var.sql_admin_login};Password=${var.sql_admin_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}
resource "azurerm_key_vault_secret" "cosmos_endpoint" { name = "cosmos-endpoint" key_vault_id = azurerm_key_vault.kv.id value = azurerm_cosmosdb_account.cosmos.endpoint }
resource "azurerm_key_vault_secret" "cosmos_key"      { name = "cosmos-primary-key" key_vault_id = azurerm_key_vault.kv.id value = azurerm_cosmosdb_account.cosmos.primary_key }
resource "azurerm_key_vault_secret" "redis_conn"      { name = "redis-primary-connection-string" key_vault_id = azurerm_key_vault.kv.id value = "${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port},password=${azurerm_redis_cache.redis.primary_access_key},ssl=True,abortConnect=False" }
resource "azurerm_key_vault_secret" "appinsights_conn" { name = "application-insights-connection-string" key_vault_id = azurerm_key_vault.kv.id value = azurerm_application_insights.appi.connection_string }
resource "azurerm_key_vault_secret" "appcfg_endpoint" { name = "appconfig-endpoint" key_vault_id = azurerm_key_vault.kv.id value = azurerm_app_configuration.appcfg.endpoint }
# Optionally store B2C IDs:
# resource "azurerm_key_vault_secret" "b2c_api_appid" { name = "b2c-api-client-id" value = "<GUID>" key_vault_id = azurerm_key_vault.kv.id }
