#!/bin/bash
set -e

echo "=== Extracting Infrastructure Connection Details ==="

# Change to Terraform directory
cd terraform/deployments/control-plane/azure

# Extract outputs
POSTGRES_HOST=$(terraform output -raw postgres_server_fqdn)
POSTGRES_DB=$(terraform output -raw postgres_database_name)
POSTGRES_USER=$(terraform output -raw postgres_admin_username)
POSTGRES_PASSWORD=$(terraform output -raw postgres_admin_password)

REDIS_HOST=$(terraform output -raw redis_hostname)
REDIS_PORT=$(terraform output -raw redis_ssl_port)
REDIS_PASSWORD=$(terraform output -raw redis_primary_access_key)

AKS_RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)

# Get AKS credentials
echo "Getting AKS credentials..."
az aks get-credentials --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing

# Verify cluster access
echo "Verifying cluster access..."
kubectl cluster-info

# Create environment file for Helm deployment
cat > ../../../../kubernetes/tyk-control-plane/infrastructure.env << EOF
POSTGRES_HOST='$POSTGRES_HOST'
POSTGRES_DB='$POSTGRES_DB'
POSTGRES_USER='$POSTGRES_USER'
POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
REDIS_HOST='$REDIS_HOST'
REDIS_PORT='$REDIS_PORT'
REDIS_PASSWORD='$REDIS_PASSWORD'
AKS_RESOURCE_GROUP='$AKS_RESOURCE_GROUP'
AKS_CLUSTER_NAME='$AKS_CLUSTER_NAME'
EOF

echo "Infrastructure details extracted to kubernetes/tyk-control-plane/infrastructure.env"
echo "✅ Infrastructure setup complete!"