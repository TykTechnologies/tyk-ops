# Deployment Guide

Instructions for deploying Tyk Control Plane infrastructure on Azure.

## Prerequisites

### Required Tools Installation

**Azure CLI**
```bash
# macOS (using Homebrew)
brew install azure-cli

# Verify installation
az --version
```

**Terraform**
```bash
# macOS (using Homebrew)
brew install terraform

# Verify installation
terraform --version
```

**kubectl**
```bash
# macOS (using Homebrew)
brew install kubectl

# Verify installation
kubectl version --client
```

### Azure Authentication
```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Verify you're using the right subscription
az account show
```

## Deployment Steps

### 1. Navigate to the control plane directory
```bash
cd terraform/deployments/control-plane/azure
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Choose and review configuration

Pick one of the example configurations:
- `examples/dev.tfvars` - Basic setup for development
- `examples/staging.tfvars` - Mid-sized configuration
- `examples/prod.tfvars` - Production setup with high availability

Copy and modify as needed:
```bash
cp examples/dev.tfvars my-config.tfvars
# Edit my-config.tfvars with your preferred settings
```

### 4. Plan the deployment
```bash
terraform plan -var-file="my-config.tfvars"
```

Review what will be created before proceeding.

### 5. Apply the configuration
```bash
terraform apply -var-file="my-config.tfvars"
```

Deployment usually takes 10-15 minutes.

### 6. Access the cluster
```bash
# Configure kubectl
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw aks_cluster_name)

# Test connectivity
kubectl get nodes
```

## Useful Outputs

After deployment, you can get connection information:

```bash
# PostgreSQL connection string
terraform output postgres_connection_string

# Redis connection info
terraform output redis_connection_string

# Get passwords (sensitive data)
terraform output -raw postgres_admin_password
terraform output -raw redis_primary_access_key
```

## Database Access

### Connect to PostgreSQL
```bash
kubectl run postgres-client --image=postgres:15 --rm -it --restart=Never -- bash
# Inside the pod:
# psql "$(terraform output -raw postgres_connection_string)"
```

### Connect to Redis
```bash
kubectl run redis-client --image=redis:7 --rm -it --restart=Never -- bash
# Inside the pod:
# redis-cli -h $(terraform output -raw redis_hostname) -p $(terraform output -raw redis_ssl_port) --tls
```

## Common Configuration Changes

### Custom resource names
```hcl
resource_group_name = "my-custom-rg"
aks_cluster_name = "my-tyk-cluster"
```

### Use existing VNet
```hcl
create_vnet = false
# You'll need to provide existing VNet details
```

### Disable Key Vault
```hcl
enable_key_vault = false
```

## Troubleshooting

### Common errors

**Insufficient permissions**
```
Error: insufficient privileges to complete the operation
```
Your Azure account needs Contributor or Owner permissions.

**Resource name conflicts**
```
Error: A resource with the name "xxx" already exists
```
Try custom resource names or a different Azure region.

**Quota exceeded**
```
Error: quota exceeded for resource type
```
Request quota increase in Azure portal or use smaller VM sizes.

### Debug steps
```bash
# Enable debug logging
TF_LOG=DEBUG terraform apply

# Check cluster status
az aks show --name <cluster-name> --resource-group <rg-name>
```

## Cleanup

```bash
terraform destroy -var-file="my-config.tfvars"
```

This will delete all resources. Make sure you have backups if needed.
