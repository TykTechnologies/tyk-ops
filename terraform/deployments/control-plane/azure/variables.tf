# General Configuration
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "tyk-control-plane"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group. If not provided, will be generated"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "tyk-ops"
    Component   = "control-plane"
    ManagedBy   = "terraform"
  }
}

# AKS Configuration
variable "aks_cluster_name" {
  description = "Name of the AKS cluster. If not provided, will be generated"
  type        = string
  default     = ""
}

variable "aks_node_count" {
  description = "Initial number of nodes in the AKS cluster"
  type        = number
  default     = 2
}

variable "aks_node_size" {
  description = "Size of the AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = null
}

variable "aks_enable_auto_scaling" {
  description = "Enable auto-scaling for AKS node pool"
  type        = bool
  default     = true
}

variable "aks_min_count" {
  description = "Minimum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 1
}

variable "aks_max_count" {
  description = "Maximum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 5
}

# AKS Network Configuration
variable "aks_network_plugin" {
  description = "Network plugin for AKS cluster"
  type        = string
  default     = "azure"
}

variable "aks_service_cidr" {
  description = "Service CIDR for AKS cluster"
  type        = string
  default     = "10.240.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "DNS service IP for AKS cluster"
  type        = string
  default     = "10.240.0.10"
}

# PostgreSQL Configuration
variable "postgres_server_name" {
  description = "Name of the PostgreSQL server. If not provided, will be generated"
  type        = string
  default     = ""
}

variable "postgres_sku_name" {
  description = "SKU name for PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Storage size in MB for PostgreSQL"
  type        = number
  default     = 32768
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "13"
}

variable "postgres_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "tykadmin"
}

variable "postgres_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "postgres_high_availability_enabled" {
  description = "Enable high availability for PostgreSQL"
  type        = bool
  default     = false
}

# Redis Configuration
variable "redis_cache_name" {
  description = "Name of the Redis cache. If not provided, will be generated"
  type        = string
  default     = ""
}

variable "redis_capacity" {
  description = "Redis cache capacity"
  type        = number
  default     = 1
}

variable "redis_family" {
  description = "Redis cache family (C for Basic/Standard, P for Premium)"
  type        = string
  default     = "C"
}

variable "redis_sku_name" {
  description = "Redis cache SKU name"
  type        = string
  default     = "Basic"
}

variable "redis_enable_non_ssl_port" {
  description = "Enable non-SSL port for Redis"
  type        = bool
  default     = false
}

# Redis Persistence Configuration
variable "redis_enable_persistence" {
  description = "Enable Redis RDB persistence (requires Premium SKU)"
  type        = bool
  default     = true
}

variable "redis_rdb_backup_enabled" {
  description = "Enable RDB backup for Redis persistence"
  type        = bool
  default     = true
}

variable "redis_rdb_backup_frequency" {
  description = "RDB backup frequency in minutes (60, 360, 720, 1440)"
  type        = number
  default     = 360
  validation {
    condition     = contains([60, 360, 720, 1440], var.redis_rdb_backup_frequency)
    error_message = "RDB backup frequency must be one of: 60, 360, 720, 1440 minutes."
  }
}

variable "redis_rdb_backup_max_snapshot_count" {
  description = "Maximum number of RDB snapshots to retain"
  type        = number
  default     = 1
}

# Redis Clustering Configuration
variable "redis_enable_clustering" {
  description = "Enable Redis clustering (requires Premium SKU)"
  type        = bool
  default     = false
}

variable "redis_shard_count" {
  description = "Number of shards for Redis cluster (only when clustering enabled)"
  type        = number
  default     = 1
  validation {
    condition     = var.redis_shard_count >= 1 && var.redis_shard_count <= 10
    error_message = "Redis shard count must be between 1 and 10."
  }
}

# Key Vault Configuration
variable "enable_key_vault" {
  description = "Enable Azure Key Vault for secrets management"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Name of the Key Vault. If not provided, will be generated"
  type        = string
  default     = ""
}

variable "key_vault_sku" {
  description = "SKU for Key Vault"
  type        = string
  default     = "standard"
}

# Networking Configuration
variable "create_vnet" {
  description = "Create a new virtual network or use existing one"
  type        = bool
  default     = true
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = ""
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for AKS subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "database_subnet_address_prefixes" {
  description = "Address prefixes for database subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "private_endpoint_subnet_address_prefixes" {
  description = "Address prefixes for private endpoint subnet"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}