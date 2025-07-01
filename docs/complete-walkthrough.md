# End-to-End Deployment

This guide walks through deploying Tyk infrastructure from start to finish.

## What you'll deploy

- AKS cluster for running Tyk components
- PostgreSQL database for storing API definitions and analytics
- Redis cache for rate limiting and session data
- Networking setup with security-focused defaults

## Step 1: Deploy Infrastructure

```bash
cd terraform/deployments/control-plane/azure
terraform init
terraform plan -var-file="examples/dev.tfvars"
terraform apply -var-file="examples/dev.tfvars"
```

This creates:
- Resource group containing all resources
- AKS cluster with 2 nodes (configurable)
- PostgreSQL Flexible Server with private access
- Redis cache instance
- Virtual network with subnets for different components

## Step 2: Access the cluster

```bash
# Configure kubectl
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw aks_cluster_name)

# Verify cluster access
kubectl get nodes
```

## Configuration Options

### Environment Examples

- `examples/dev.tfvars` - Basic development setup
- `examples/staging.tfvars` - Mid-sized configuration
- `examples/prod.tfvars` - Production setup with HA

### Common Customizations

```hcl
# Adjust cluster size
aks_node_count = 3
aks_node_size = "Standard_D2s_v3"

# Enable PostgreSQL high availability
postgres_high_availability_enabled = true

# Use larger Redis instance
redis_capacity = 2
redis_sku_name = "Standard"

# Disable Key Vault if you have your own secrets management
enable_key_vault = false
```

## Database Access

For troubleshooting or initial setup:

```bash
# PostgreSQL
kubectl run postgres-client --image=postgres:15 --rm -it --restart=Never -- bash
# Then: psql "connection-string-from-terraform-output"

# Redis
kubectl run redis-client --image=redis:7 --rm -it --restart=Never -- bash
# Then: redis-cli -h hostname -p port --tls
```

## Cleanup

```bash
terraform destroy -var-file="examples/dev.tfvars"
```

This removes all created resources. Make sure you have backups of any important data.
