#!/bin/bash

# Tyk Control Plane Setup Script
# Simple setup for Kubernetes secrets without Key Vault dependency

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Environment Configuration from Terraform outputs
export RESOURCE_GROUP="tyk-control-plane-dev-rg"
export AKS_CLUSTER_NAME="tyk-control-plane-dev-aks"

log_info "Tyk Control Plane Environment Setup"
log_info "Resource Group: $RESOURCE_GROUP"
log_info "AKS Cluster: $AKS_CLUSTER_NAME"

# Check if .env file exists
if [ ! -f .env ]; then
    log_error ".env file not found. Please create it from .env.template and add your license keys."
    exit 1
fi

# Source license configuration
source .env

# Validate critical licenses
if [ "$DASHBOARD_LICENSE" = "YOUR_DASHBOARD_LICENSE_HERE" ]; then
    log_error "Dashboard license not configured in .env file"
    exit 1
fi

if [ "$MDCB_LICENSE" = "YOUR_MDCB_LICENSE_HERE" ]; then
    log_error "MDCB license not configured in .env file"
    exit 1
fi

log_success "Environment configuration loaded successfully"

# Get infrastructure details from Terraform outputs
get_terraform_outputs() {
    log_info "Getting infrastructure details from Terraform..."
    
    cd ../../terraform/deployments/control-plane/azure
    
    if [ ! -f terraform.tfstate ]; then
        log_error "Terraform state not found. Please run 'terraform apply' first."
        exit 1
    fi
    
    export POSTGRES_HOST=$(terraform output -raw postgres_server_fqdn)
    export POSTGRES_USER=$(terraform output -raw postgres_admin_username)
    export POSTGRES_PASSWORD=$(terraform output -raw postgres_admin_password)
    export POSTGRES_DATABASE=$(terraform output -raw postgres_database_name)
    export REDIS_HOST=$(terraform output -raw redis_hostname)
    export REDIS_PORT=$(terraform output -raw redis_ssl_port)
    export REDIS_PASSWORD=$(terraform output -raw redis_primary_access_key)
    
    cd - > /dev/null
    
    log_success "Infrastructure details retrieved from Terraform"
}

# Create Kubernetes secrets directly
create_kubernetes_secrets() {
    log_info "Creating Kubernetes secrets..."
    
    # Ensure tyk namespace exists
    kubectl create namespace tyk --dry-run=client -o yaml | kubectl apply -f -
    
    # Generate secure API and admin secrets
    API_SECRET=$(openssl rand -base64 32)
    ADMIN_SECRET=$(openssl rand -base64 32)
    SECURITY_SECRET=$(openssl rand -base64 32)
    
    # Create PostgreSQL secrets
    kubectl create secret generic tyk-postgres-secret -n tyk \
        --from-literal=postgres-host="$POSTGRES_HOST" \
        --from-literal=postgres-user="$POSTGRES_USER" \
        --from-literal=postgres-password="$POSTGRES_PASSWORD" \
        --from-literal=postgres-database="$POSTGRES_DATABASE" \
        --from-literal=postgres-connection-string="host=$POSTGRES_HOST port=5432 user=$POSTGRES_USER password=$POSTGRES_PASSWORD dbname=$POSTGRES_DATABASE sslmode=require" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Redis secrets
    kubectl create secret generic tyk-redis-secret -n tyk \
        --from-literal=redis-host="$REDIS_HOST" \
        --from-literal=redis-port="$REDIS_PORT" \
        --from-literal=redis-password="$REDIS_PASSWORD" \
        --from-literal=redis-addrs="$REDIS_HOST:$REDIS_PORT" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create main Tyk secrets
    kubectl create secret generic tyk-secrets -n tyk \
        --from-literal=DashLicense="$DASHBOARD_LICENSE" \
        --from-literal=OperatorLicense="$OPERATOR_LICENSE" \
        --from-literal=APISecret="$API_SECRET" \
        --from-literal=AdminSecret="$ADMIN_SECRET" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create MDCB secrets
    kubectl create secret generic tyk-mdcb-secret -n tyk \
        --from-literal=MDCBLicense="$MDCB_LICENSE" \
        --from-literal=securitySecret="$SECURITY_SECRET" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create admin user secrets
    kubectl create secret generic tyk-admin-user-secret -n tyk \
        --from-literal=adminUserFirstName="$ADMIN_FIRST_NAME" \
        --from-literal=adminUserLastName="$ADMIN_LAST_NAME" \
        --from-literal=adminUserEmail="$ADMIN_EMAIL" \
        --from-literal=adminUserPassword="$ADMIN_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Developer Portal secrets
    kubectl create secret generic tyk-dev-portal-secret -n tyk \
        --from-literal=DevPortalLicense="$PORTAL_LICENSE" \
        --from-literal=DevPortalDatabaseConnectionString="host=$POSTGRES_HOST port=5432 user=$POSTGRES_USER password=$POSTGRES_PASSWORD dbname=$POSTGRES_DATABASE sslmode=require" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create dev portal bootstrap secret (for Helm chart compatibility)
    kubectl create secret generic secrets-tyk-cp-tyk-dev-portal -n tyk \
        --from-literal=adminUserPassword="$ADMIN_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Kubernetes secrets created successfully"
}

# Setup Kubernetes cluster access
setup_cluster() {
    log_info "Setting up AKS cluster access..."
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing > /dev/null
    
    # Verify cluster connectivity
    kubectl cluster-info --request-timeout=10s > /dev/null
    if [ $? -ne 0 ]; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "AKS cluster access configured"
}

# Main execution
if [ "$1" = "--create-secrets" ] || [ "$1" = "--all" ]; then
    get_terraform_outputs
    create_kubernetes_secrets
fi

if [ "$1" = "--setup-cluster" ] || [ "$1" = "--all" ]; then
    setup_cluster
fi

if [ "$1" = "" ]; then
    log_info "Usage: ./setup.sh [--create-secrets|--setup-cluster|--all]"
    log_info "  --create-secrets  Create Kubernetes secrets from Terraform outputs and .env"
    log_info "  --setup-cluster   Configure AKS cluster access"
    log_info "  --all            Run both create-secrets and setup-cluster"
    exit 0
fi

log_success "Setup completed successfully!"