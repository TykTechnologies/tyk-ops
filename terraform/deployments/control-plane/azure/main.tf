# Local values for resource naming and configuration
locals {
  # Generate resource names if not provided
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "${var.project_name}-${var.environment}-rg"
  aks_cluster_name    = var.aks_cluster_name != "" ? var.aks_cluster_name : "${var.project_name}-${var.environment}-aks"
  postgres_server_name = var.postgres_server_name != "" ? var.postgres_server_name : "${var.project_name}-${var.environment}-postgres"
  redis_cache_name    = var.redis_cache_name != "" ? var.redis_cache_name : "${var.project_name}-${var.environment}-redis"
  vnet_name          = var.vnet_name != "" ? var.vnet_name : "${var.project_name}-${var.environment}-vnet"

  # Common tags
  common_tags = merge(var.tags, {
    Environment = var.environment
  })
}

# Generate random password for PostgreSQL (URL-safe characters only)
resource "random_password" "postgres_admin_password" {
  length  = 20
  special = true
  # Only use URL-safe special characters
  override_special = "-_."
}

# Data source to get current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  count               = var.create_vnet ? 1 : 0
  name                = local.vnet_name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# AKS Subnet
resource "azurerm_subnet" "aks" {
  count                = var.create_vnet ? 1 : 0
  name                 = "${local.aks_cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = var.aks_subnet_address_prefixes
}

# Database Subnet
resource "azurerm_subnet" "database" {
  count                = var.create_vnet ? 1 : 0
  name                 = "database-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = var.database_subnet_address_prefixes
  
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private Endpoint Subnet
resource "azurerm_subnet" "private_endpoint" {
  count                = var.create_vnet ? 1 : 0
  name                 = "private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = var.private_endpoint_subnet_address_prefixes
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${local.aks_cluster_name}-dns"
  kubernetes_version  = var.aks_kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.aks_enable_auto_scaling ? null : var.aks_node_count
    vm_size             = var.aks_node_size
    vnet_subnet_id      = var.create_vnet ? azurerm_subnet.aks[0].id : null
    enable_auto_scaling = var.aks_enable_auto_scaling
    min_count          = var.aks_enable_auto_scaling ? var.aks_min_count : null
    max_count          = var.aks_enable_auto_scaling ? var.aks_max_count : null
  }

  network_profile {
    network_plugin = var.aks_network_plugin
    service_cidr   = var.aks_service_cidr
    dns_service_ip = var.aks_dns_service_ip
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  count               = var.create_vnet ? 1 : 0
  name                = "${local.postgres_server_name}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Private DNS Zone Virtual Network Link for PostgreSQL
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = var.create_vnet ? 1 : 0
  name                  = "${local.postgres_server_name}-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = azurerm_virtual_network.main[0].id
  resource_group_name   = azurerm_resource_group.main.name
  tags                  = local.common_tags
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                          = local.postgres_server_name
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = var.postgres_version
  delegated_subnet_id           = var.create_vnet ? azurerm_subnet.database[0].id : null
  private_dns_zone_id           = var.create_vnet ? azurerm_private_dns_zone.postgres[0].id : null
  public_network_access_enabled = var.create_vnet ? false : true
  administrator_login           = var.postgres_admin_username
  administrator_password        = random_password.postgres_admin_password.result
  zone                          = "1"
  
  storage_mb        = var.postgres_storage_mb
  sku_name          = var.postgres_sku_name
  backup_retention_days = var.postgres_backup_retention_days

  dynamic "high_availability" {
    for_each = var.postgres_high_availability_enabled ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

# PostgreSQL Database for Tyk
resource "azurerm_postgresql_flexible_server_database" "tyk" {
  name      = "tyk"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Redis Cache
resource "azurerm_redis_cache" "main" {
  name                = local.redis_cache_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = var.redis_capacity
  family              = var.redis_enable_persistence || var.redis_enable_clustering ? "P" : var.redis_family
  sku_name            = var.redis_enable_persistence || var.redis_enable_clustering ? "Premium" : var.redis_sku_name
  shard_count         = var.redis_enable_clustering ? var.redis_shard_count : null
  non_ssl_port_enabled = var.redis_enable_non_ssl_port
  minimum_tls_version = "1.2"

  # Redis configuration for Basic/Standard tiers
  dynamic "redis_configuration" {
    for_each = var.redis_family == "C" ? [1] : []
    content {
      authentication_enabled = true
      maxmemory_policy       = "volatile-lru"
    }
  }

  # Redis configuration for Premium tier with RDB options
  dynamic "redis_configuration" {
    for_each = var.redis_family == "P" || var.redis_enable_clustering || var.redis_enable_persistence ? [1] : []
    content {
      authentication_enabled = true
      maxmemory_policy       = "volatile-lru"
      rdb_backup_enabled            = var.redis_rdb_backup_enabled
      rdb_backup_frequency          = var.redis_rdb_backup_enabled ? var.redis_rdb_backup_frequency : null
      rdb_backup_max_snapshot_count = var.redis_rdb_backup_enabled ? var.redis_rdb_backup_max_snapshot_count : null
    }
  }

  tags = local.common_tags
}
