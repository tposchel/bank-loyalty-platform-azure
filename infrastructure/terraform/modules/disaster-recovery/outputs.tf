output "secondary_sql_server_id" {
  description = "Secondary SQL Server ID"
  value       = azurerm_mssql_server.secondary.id
}

output "secondary_sql_server_fqdn" {
  description = "Secondary SQL Server FQDN"
  value       = azurerm_mssql_server.secondary.fully_qualified_domain_name
}

output "failover_group_id" {
  description = "SQL Failover Group ID"
  value       = azurerm_mssql_failover_group.main.id
}

output "failover_group_read_write_endpoint" {
  description = "Failover group read-write endpoint"
  value       = "${azurerm_mssql_failover_group.main.name}.database.windows.net"
}

output "failover_group_readonly_endpoint" {
  description = "Failover group read-only endpoint"
  value       = "${azurerm_mssql_failover_group.main.name}.secondary.database.windows.net"
}

output "traffic_manager_fqdn" {
  description = "Traffic Manager FQDN"
  value       = azurerm_traffic_manager_profile.main.fqdn
}

output "traffic_manager_profile_id" {
  description = "Traffic Manager profile ID"
  value       = azurerm_traffic_manager_profile.main.id
}

output "secondary_redis_id" {
  description = "Secondary Redis cache ID"
  value       = var.enable_redis_dr ? azurerm_redis_cache.secondary[0].id : null
}
