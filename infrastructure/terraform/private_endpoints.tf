resource "azurerm_private_dns_zone" "kv"     { name = "privatelink.vaultcore.azure.net"   resource_group_name = azurerm_resource_group.rg.name }
resource "azurerm_private_dns_zone" "sql"    { name = "privatelink.database.windows.net"  resource_group_name = azurerm_resource_group.rg.name }
resource "azurerm_private_dns_zone" "cosmos" { name = "privatelink.documents.azure.com"    resource_group_name = azurerm_resource_group.rg.name }
resource "azurerm_private_dns_zone" "redis"  { name = "privatelink.redis.cache.windows.net" resource_group_name = azurerm_resource_group.rg.name }
resource "azurerm_private_dns_zone" "appcfg" { name = "privatelink.azconfig.io"            resource_group_name = azurerm_resource_group.rg.name }

resource "azurerm_private_dns_zone_virtual_network_link" "kv"     { name = "${local.base}-kv-link"     private_dns_zone_name = azurerm_private_dns_zone.kv.name     resource_group_name = azurerm_resource_group.rg.name virtual_network_id = azurerm_virtual_network.vnet.id registration_enabled = false }
resource "azurerm_private_dns_zone_virtual_network_link" "sql"    { name = "${local.base}-sql-link"    private_dns_zone_name = azurerm_private_dns_zone.sql.name    resource_group_name = azurerm_resource_group.rg.name virtual_network_id = azurerm_virtual_network.vnet.id registration_enabled = false }
resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" { name = "${local.base}-cosmos-link" private_dns_zone_name = azurerm_private_dns_zone.cosmos.name resource_group_name = azurerm_resource_group.rg.name virtual_network_id = azurerm_virtual_network.vnet.id registration_enabled = false }
resource "azurerm_private_dns_zone_virtual_network_link" "redis"  { name = "${local.base}-redis-link"  private_dns_zone_name = azurerm_private_dns_zone.redis.name  resource_group_name = azurerm_resource_group.rg.name virtual_network_id = azurerm_virtual_network.vnet.id registration_enabled = false }
resource "azurerm_private_dns_zone_virtual_network_link" "appcfg" { name = "${local.base}-appcfg-link" private_dns_zone_name = azurerm_private_dns_zone.appcfg.name resource_group_name = azurerm_resource_group.rg.name virtual_network_id = azurerm_virtual_network.vnet.id registration_enabled = false }

resource "azurerm_private_endpoint" "kv" {
  name                = "${local.base}-kv-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks.id
  private_service_connection { name = "kv" private_connection_resource_id = azurerm_key_vault.kv.id subresource_names = ["vault"] is_manual_connection = false }
  private_dns_zone_group { name = "kv-zone" private_dns_zone_ids = [azurerm_private_dns_zone.kv.id] }
  tags = local.tags
}
resource "azurerm_private_endpoint" "sql" {
  name                = "${local.base}-sql-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks.id
  private_service_connection { name = "sql" private_connection_resource_id = azurerm_mssql_server.sql.id subresource_names = ["sqlServer"] is_manual_connection = false }
  private_dns_zone_group { name = "sql-zone" private_dns_zone_ids = [azurerm_private_dns_zone.sql.id] }
  tags = local.tags
}
resource "azurerm_private_endpoint" "cosmos" {
  name                = "${local.base}-cosmos-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks.id
  private_service_connection { name = "cosmos" private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id subresource_names = ["Sql"] is_manual_connection = false }
  private_dns_zone_group { name = "cosmos-zone" private_dns_zone_ids = [azurerm_private_dns_zone.cosmos.id] }
  tags = local.tags
}
resource "azurerm_private_endpoint" "redis" {
  name                = "${local.base}-redis-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks.id
  private_service_connection { name = "redis" private_connection_resource_id = azurerm_redis_cache.redis.id subresource_names = ["redisCache"] is_manual_connection = false }
  private_dns_zone_group { name = "redis-zone" private_dns_zone_ids = [azurerm_private_dns_zone.redis.id] }
  tags = local.tags
}
resource "azurerm_private_endpoint" "appcfg" {
  name                = "${local.base}-appcfg-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks.id
  private_service_connection { name = "appcfg" private_connection_resource_id = azurerm_app_configuration.appcfg.id subresource_names = ["configurationStores"] is_manual_connection = false }
  private_dns_zone_group { name = "appcfg-zone" private_dns_zone_ids = [azurerm_private_dns_zone.appcfg.id] }
  tags = local.tags
}
