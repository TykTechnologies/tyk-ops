# Resource Group
output "resource_group_name" {
  description = "Name of the resource group containing all resources"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# AKS Cluster
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_cluster_kubernetes_version" {
  description = "Kubernetes version of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kubernetes_version
}

output "aks_kubeconfig_command" {
  description = "Command to get kubeconfig for the AKS cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

# PostgreSQL
output "postgres_server_name" {
  description = "Name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgres_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_database_name" {
  description = "Name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.tyk.name
}

output "postgres_admin_username" {
  description = "Administrator username for PostgreSQL"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.tyk.name}"
  sensitive   = false
}

# Redis
output "redis_cache_name" {
  description = "Name of the Redis cache"
  value       = azurerm_redis_cache.main.name
}

output "redis_hostname" {
  description = "Hostname of the Redis cache"
  value       = azurerm_redis_cache.main.hostname
}

output "redis_ssl_port" {
  description = "SSL port of the Redis cache"
  value       = azurerm_redis_cache.main.ssl_port
}

output "redis_port" {
  description = "Non-SSL port of the Redis cache"
  value       = azurerm_redis_cache.main.port
}

output "redis_connection_string" {
  description = "Redis connection string (SSL)"
  value       = "${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port}"
}

# Networking
output "vnet_name" {
  description = "Name of the virtual network (if created)"
  value       = var.create_vnet ? azurerm_virtual_network.main[0].name : null
}

output "vnet_id" {
  description = "ID of the virtual network (if created)"
  value       = var.create_vnet ? azurerm_virtual_network.main[0].id : null
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet (if created)"
  value       = var.create_vnet ? azurerm_subnet.aks[0].id : null
}

# Sensitive Outputs
output "postgres_admin_password" {
  description = "Administrator password for PostgreSQL"
  value       = random_password.postgres_admin_password.result
  sensitive   = true
}

output "redis_primary_access_key" {
  description = "Primary access key for Redis"
  value       = azurerm_redis_cache.main.primary_access_key
  sensitive   = true
}

output "redis_secondary_access_key" {
  description = "Secondary access key for Redis"
  value       = azurerm_redis_cache.main.secondary_access_key
  sensitive   = true
}

# Connection Information for Data Planes
output "data_plane_connection_info" {
  description = "Connection information for data plane deployments"
  value = {
    resource_group_name = azurerm_resource_group.main.name
    location           = azurerm_resource_group.main.location
    aks_cluster_name   = azurerm_kubernetes_cluster.main.name
    postgres_fqdn      = azurerm_postgresql_flexible_server.main.fqdn
    postgres_database  = azurerm_postgresql_flexible_server_database.tyk.name
    redis_hostname     = azurerm_redis_cache.main.hostname
    redis_ssl_port     = azurerm_redis_cache.main.ssl_port
    vnet_id           = var.create_vnet ? azurerm_virtual_network.main[0].id : null
  }
}