# Production Environment Configuration
# This configuration includes Redis clustering and enhanced persistence for production workloads

environment = "prod"
project_name = "tyk-control-plane"

# Region Options - Uncomment the desired region, comment out all others
location = "East US"              # Virginia (US production)

# AKS Configuration - Production cluster with robust scaling
aks_node_count = 5
aks_node_size = "Standard_D4s_v3"  # 4 vCPU, 16 GB RAM
aks_enable_auto_scaling = true
aks_min_count = 3
aks_max_count = 10

# PostgreSQL Configuration - High-performance tier for production
postgres_sku_name = "GP_Standard_D4s_v3"  # 4 vCPU, 16 GB RAM
postgres_storage_mb = 131072  # 128 GB
postgres_backup_retention_days = 35  # Extended retention
postgres_high_availability_enabled = true  # Zone redundant HA

# Redis Configuration - Premium with clustering for production scale
# P3 Premium provides sufficient capacity for 6-node cluster (3 shards + 3 replicas)
redis_capacity = 26  # 26 GB (P3 Premium) - supports high availability clustering
redis_family = "P"  # Premium family (required for clustering and replicas)
redis_sku_name = "Premium"
redis_enable_non_ssl_port = false

# Redis Persistence - Enhanced backup strategy for production
redis_enable_persistence = true
redis_rdb_backup_enabled = true
redis_rdb_backup_frequency = 360  # 6 hours
redis_rdb_backup_max_snapshot_count = 5  # Keep 5 snapshots for production

# Redis Clustering - 6-node cluster for production performance and reliability
# 3 primary shards + 3 replica nodes (1 replica per shard) = 6 total nodes
redis_enable_clustering = true
redis_shard_count = 3  # 3 primary shards with automatic replica provisioning

# Networking Configuration
create_vnet = true
vnet_address_space = ["10.2.0.0/16"]
aks_subnet_address_prefixes = ["10.2.1.0/24"]
database_subnet_address_prefixes = ["10.2.2.0/24"]
private_endpoint_subnet_address_prefixes = ["10.2.3.0/24"]

# Tags
tags = {
  Project = "tyk-ops"
  Component = "control-plane"
  Environment = "prod"
  ManagedBy = "terraform"
  Owner = "platform-team"
  Region = "east-us"
  DataClassification = "confidential"
  BackupRequired = "true"
  MonitoringLevel = "enhanced"
}