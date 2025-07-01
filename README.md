# Tyk-Ops

Infrastructure as code for deploying Tyk API Management on cloud providers, starting with Azure.

## What this provides

- Terraform configuration for Tyk Control Plane infrastructure
- Azure Kubernetes Service (AKS) cluster setup
- PostgreSQL and Redis configuration
- Optional Azure Key Vault integration
- Example configurations for different environments

## Components

### Control Plane Infrastructure
- AKS cluster for running Tyk components
- PostgreSQL Flexible Server for data storage
- Redis Cache for session and rate limiting data
- Virtual network with security-focused subnets

### Deployment Options
- Single environment deployment
- Configurable resource sizing
- Optional secrets management with Key Vault

## Getting Started

### Prerequisites
- Azure CLI installed and configured
- Terraform >= 1.0
- kubectl (for accessing the cluster after deployment)

### Basic Deployment
```bash
cd terraform/deployments/control-plane/azure
terraform init
terraform plan -var-file="examples/dev.tfvars"
terraform apply -var-file="examples/dev.tfvars"
```

### Access the cluster
```bash
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw aks_cluster_name)
kubectl get nodes
```

## Configuration

Three example configurations are provided:
- `examples/dev.tfvars` - Basic setup for development
- `examples/staging.tfvars` - Mid-sized configuration
- `examples/prod.tfvars` - Production-ready with high availability

You can copy and modify these files to match your requirements.

## Documentation

- [Deployment Guide](docs/terraform/deployment-guide.md) - Step by step instructions
- [Architecture Notes](docs/terraform/architecture-decisions.md) - Design decisions and rationale
- [Complete Walkthrough](docs/complete-walkthrough.md) - End-to-end deployment process

## Cleanup

```bash
terraform destroy -var-file="examples/dev.tfvars"
```