# Development Environment Configuration - Global Regions
# This configuration is optimized for development workloads with easy region switching

environment = "dev"
project_name = "tyk-control-plane"

# Region Options - Uncomment the desired region, comment out all others

# Europe
# location = "West Europe"          # Netherlands
location = "Switzerland North"      # Zurich area (ACTIVE)
# location = "Germany West Central" # Frankfurt area

# UK
# location = "UK South"             # London area

# United States
# location = "East US"              # Virginia
# location = "West US 2"            # Washington State

# Asia Pacific
# location = "Southeast Asia"       # Singapore
# location = "East Asia"            # Hong Kong

# AKS Configuration - Small cluster for development
aks_node_count = 2
aks_node_size = "Standard_B2s"  # 2 vCPU, 4 GB RAM
aks_enable_auto_scaling = true
aks_min_count = 1
aks_max_count = 3

# PostgreSQL Configuration - Burstable tier for development
postgres_sku_name = "B_Standard_B1ms"  # 1 vCPU, 2 GB RAM
postgres_storage_mb = 32768  # 32 GB
postgres_backup_retention_days = 7
postgres_high_availability_enabled = false  # Not needed for dev

# Redis Configuration - Basic tier for development (cost-effective)
redis_capacity = 1  # 1 GB
redis_family = "C"
redis_sku_name = "Basic"
redis_enable_non_ssl_port = false

# Redis Persistence - Enabled to preserve analytics, sessions, and rate limiting data
redis_enable_persistence = true
redis_rdb_backup_enabled = true
redis_rdb_backup_frequency = 360
redis_rdb_backup_max_snapshot_count = 1

# Redis Clustering - Disabled for development
redis_enable_clustering = false
redis_shard_count = 1


# Networking Configuration
create_vnet = true
vnet_address_space = ["10.0.0.0/16"]
aks_subnet_address_prefixes = ["10.0.1.0/24"]
database_subnet_address_prefixes = ["10.0.2.0/24"]
private_endpoint_subnet_address_prefixes = ["10.0.3.0/24"]

# Tags
tags = {
  Project = "tyk-ops"
  Component = "control-plane"
  Environment = "dev"
  ManagedBy = "terraform"
  Owner = "platform-team"
  Region = "switzerland-north"  # Update this when changing regions
}