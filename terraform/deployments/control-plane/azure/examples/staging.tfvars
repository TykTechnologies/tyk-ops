# Staging Environment Configuration
# This configuration includes Redis persistence for data durability

environment = "staging"
project_name = "tyk-control-plane"

# Region Options - Uncomment the desired region, comment out all others
location = "West Europe"          # Netherlands (EU staging)

# AKS Configuration - Larger cluster for staging
aks_node_count = 3
aks_node_size = "Standard_D2s_v3"  # 2 vCPU, 8 GB RAM
aks_enable_auto_scaling = true
aks_min_count = 2
aks_max_count = 5

# PostgreSQL Configuration - General Purpose tier for staging
postgres_sku_name = "GP_Standard_D2s_v3"  # 2 vCPU, 8 GB RAM
postgres_storage_mb = 65536  # 64 GB
postgres_backup_retention_days = 14
postgres_high_availability_enabled = true  # Zone redundant HA

# Redis Configuration - Premium with persistence for staging
redis_capacity = 1  # 1 GB
redis_family = "P"  # Premium family
redis_sku_name = "Premium"
redis_enable_non_ssl_port = false

# Redis Persistence - Critical for staging data durability
redis_enable_persistence = true
redis_rdb_backup_enabled = true
redis_rdb_backup_frequency = 360  # 6 hours
redis_rdb_backup_max_snapshot_count = 2  # Keep 2 snapshots

# Redis Clustering - Single shard sufficient for staging
redis_enable_clustering = false
redis_shard_count = 1

# Networking Configuration
create_vnet = true
vnet_address_space = ["10.1.0.0/16"]
aks_subnet_address_prefixes = ["10.1.1.0/24"]
database_subnet_address_prefixes = ["10.1.2.0/24"]
private_endpoint_subnet_address_prefixes = ["10.1.3.0/24"]

# Tags
tags = {
  Project = "tyk-ops"
  Component = "control-plane"
  Environment = "staging"
  ManagedBy = "terraform"
  Owner = "platform-team"
  Region = "west-europe"
  DataClassification = "internal"
}