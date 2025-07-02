#!/bin/bash

# Tyk Control Plane Deployment Script
# Deploys Tyk Control Plane using Helm charts with Kubernetes secrets

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

# Environment Configuration
NAMESPACE="tyk"
HELM_RELEASE_NAME="tyk-cp"
HELM_CHART="tyk-helm/tyk-control-plane"
HELM_VALUES_FILE="values-k8s-secrets.yaml"

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed and configured
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    kubectl cluster-info --request-timeout=10s > /dev/null
    if [ $? -ne 0 ]; then
        log_error "Cannot connect to Kubernetes cluster. Run './setup.sh --setup-cluster' first."
        exit 1
    fi
    
    # Check if secrets exist
    if ! kubectl get secret tyk-secrets -n $NAMESPACE &> /dev/null; then
        log_error "Tyk secrets not found. Run './setup.sh --create-secrets' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

setup_helm_repository() {
    log_info "Setting up Helm repositories..."
    
    # Add Tyk Helm repository
    helm repo add tyk-helm https://helm.tyk.io/public/helm/charts > /dev/null 2>&1 || true
    helm repo update > /dev/null 2>&1
    
    log_success "Helm repositories configured"
}

create_values_file() {
    log_info "Creating Helm values file for Kubernetes secrets..."
    
    cat > $HELM_VALUES_FILE << 'EOF'
# Tyk Control Plane Configuration for Kubernetes Secrets
global:
  # License configuration using Kubernetes secrets
  license:
    dashboard: ""  # Will be pulled from secret
    mdcb: ""       # Will be pulled from secret
    portal: ""     # Will be pulled from secret

  # Admin user configuration using Kubernetes secrets
  adminUser:
    firstName: ""  # Will be pulled from secret
    lastName: ""   # Will be pulled from secret
    email: ""      # Will be pulled from secret
    password: ""   # Will be pulled from secret

  # API secrets using Kubernetes secrets
  secrets:
    APISecret: ""    # Will be pulled from secret
    AdminSecret: ""  # Will be pulled from secret

  # PostgreSQL configuration using Kubernetes secrets
  postgres:
    host: ""         # Will be pulled from secret
    port: 5432
    user: ""         # Will be pulled from secret
    password: ""     # Will be pulled from secret
    database: ""     # Will be pulled from secret
    sslmode: require

  # Redis configuration using Kubernetes secrets  
  redis:
    addrs: ""        # Will be pulled from secret
    password: ""     # Will be pulled from secret
    useSSL: true

# Dashboard configuration
tyk-dashboard:
  nameOverride: "dashboard"
  
  dashboard:
    # Use existing secrets instead of creating new ones
    existingSecret: "tyk-secrets"
    
  # PostgreSQL connection using existing secret
  postgres:
    existingSecret: "tyk-postgres-secret"
    secretName: "tyk-postgres-secret"
    
  # Redis connection using existing secret
  redis:
    existingSecret: "tyk-redis-secret"
    secretName: "tyk-redis-secret"

# Gateway configuration
tyk-gateway:
  nameOverride: "gateway"
  
  gateway:
    # Use existing secrets
    existingSecret: "tyk-secrets"
    
  # Redis connection using existing secret
  redis:
    existingSecret: "tyk-redis-secret"
    secretName: "tyk-redis-secret"

# MDCB configuration  
tyk-mdcb:
  nameOverride: "mdcb"
  
  mdcb:
    # Use existing secrets
    existingSecret: "tyk-mdcb-secret"
    
  # Redis connection using existing secret
  redis:
    existingSecret: "tyk-redis-secret"
    secretName: "tyk-redis-secret"

# Pump configuration
tyk-pump:
  nameOverride: "pump"
  
  pump:
    # Use existing secrets for API access
    existingSecret: "tyk-secrets"
    
  # PostgreSQL connection using existing secret
  postgres:
    existingSecret: "tyk-postgres-secret"
    secretName: "tyk-postgres-secret"
    
  # Redis connection using existing secret  
  redis:
    existingSecret: "tyk-redis-secret"
    secretName: "tyk-redis-secret"

# Developer Portal configuration
tyk-dev-portal:
  nameOverride: "dev-portal"
  
  portal:
    # Use existing secrets
    existingSecret: "tyk-dev-portal-secret"
    
  # Bootstrap job configuration
  bootstrap:
    existingSecret: "secrets-tyk-cp-tyk-dev-portal"
    
  # PostgreSQL connection using existing secret
  postgres:
    existingSecret: "tyk-postgres-secret"
    secretName: "tyk-postgres-secret"

# Operator configuration
tyk-operator:
  nameOverride: "operator"
  
  operator:
    # Use existing secrets
    existingSecret: "tyk-secrets"
EOF

    log_success "Helm values file created: $HELM_VALUES_FILE"
}

deploy_tyk() {
    log_info "Deploying Tyk Control Plane..."
    
    # Ensure namespace exists
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy using Helm
    helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART \
        --namespace $NAMESPACE \
        --values $HELM_VALUES_FILE \
        --timeout 10m \
        --wait
    
    log_success "Tyk Control Plane deployed successfully"
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Wait for pods to be ready
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=$HELM_RELEASE_NAME -n $NAMESPACE --timeout=300s
    
    # Get deployment status
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$HELM_RELEASE_NAME
    
    # Get service endpoints
    log_info "Service endpoints:"
    kubectl get services -n $NAMESPACE -l app.kubernetes.io/instance=$HELM_RELEASE_NAME
    
    log_success "Deployment verification completed"
}

# Main execution
main() {
    log_info "Starting
    # Get deployment status
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$HELM_RELEASE_NAME
    
    # Get service endpoints
    log_info "Service endpoints:"
    kubectl get services -n $NAMESPACE -l app.kubernetes.io/instance=$HELM_RELEASE_NAME
    
    log_success "Deployment verification completed"
}

# Main execution
main() {
    log_info "Starting Tyk Control Plane deployment..."
    
    check_prerequisites
    setup_helm_repository
    create_values_file
    deploy_tyk
    verify_deployment
    
    log_success "Tyk Control Plane deployment completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Access the Tyk Dashboard via the LoadBalancer service"
    log_info "2. Configure your APIs through the Tyk Dashboard"
    log_info "3. Use 'kubectl get services -n $NAMESPACE' to get service endpoints"
}

# Script execution
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi