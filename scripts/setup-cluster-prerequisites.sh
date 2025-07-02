#!/bin/bash

# Tyk Control Plane - Cluster Prerequisites Setup
# This script installs necessary prerequisites for Tyk Control Plane deployment
# Run this after Kubernetes cluster is provisioned but before deploying Tyk

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available and cluster is accessible
check_cluster_access() {
    log_info "Checking Kubernetes cluster access..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster. Please check your kubeconfig"
        exit 1
    fi
    
    local cluster_info=$(kubectl cluster-info 2>/dev/null | head -1)
    log_success "Connected to cluster: $cluster_info"
}

# Install cert-manager
install_cert_manager() {
    log_info "Installing cert-manager..."
    
    # Check if cert-manager is already installed
    if kubectl get namespace cert-manager &> /dev/null; then
        log_warning "cert-manager namespace already exists, checking deployment..."
        if kubectl get deployment -n cert-manager cert-manager &> /dev/null; then
            log_success "cert-manager is already installed"
            return 0
        fi
    fi
    
    # Install cert-manager
    log_info "Applying cert-manager CRDs and deployment..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    log_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    
    log_success "cert-manager installed and ready"
}

# Setup Helm repositories
setup_helm_repos() {
    log_info "Setting up Helm repositories..."
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Add Tyk Helm repository
    log_info "Adding Tyk Helm repository..."
    helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
    
    # Update repositories
    log_info "Updating Helm repositories..."
    helm repo update
    
    log_success "Helm repositories configured"
}

# Install Tyk Operator CRDs
install_tyk_operator_crds() {
    log_info "Installing Tyk Operator CRDs..."
    
    # Check if CRDs are already installed
    if kubectl get crd apidefinitions.tyk.tyk.io &> /dev/null; then
        log_success "Tyk Operator CRDs already installed"
        return 0
    fi
    
    # Install Tyk Operator CRDs
    log_info "Applying Tyk Operator CRDs..."
    kubectl apply -f https://raw.githubusercontent.com/TykTechnologies/tyk-operator/master/helm/crds/crds.yaml
    
    log_success "Tyk Operator CRDs installed"
}

# Create tyk namespace
create_tyk_namespace() {
    log_info "Creating tyk namespace..."
    
    if kubectl get namespace tyk &> /dev/null; then
        log_warning "tyk namespace already exists"
    else
        kubectl create namespace tyk
        log_success "tyk namespace created"
    fi
}

# Verify prerequisites
verify_prerequisites() {
    log_info "Verifying prerequisites..."
    
    # Check cert-manager
    if kubectl get deployment -n cert-manager cert-manager &> /dev/null; then
        local cert_manager_ready=$(kubectl get deployment -n cert-manager cert-manager -o jsonpath='{.status.readyReplicas}')
        if [[ "$cert_manager_ready" -gt 0 ]]; then
            log_success "✅ cert-manager is running ($cert_manager_ready replicas ready)"
        else
            log_error "❌ cert-manager is not ready"
            return 1
        fi
    else
        log_error "❌ cert-manager is not installed"
        return 1
    fi
    
    # Check Tyk Operator CRDs
    if kubectl get crd apidefinitions.tyk.tyk.io &> /dev/null; then
        log_success "✅ Tyk Operator CRDs installed"
    else
        log_error "❌ Tyk Operator CRDs not installed"
        return 1
    fi
    
    # Check tyk namespace
    if kubectl get namespace tyk &> /dev/null; then
        log_success "✅ tyk namespace exists"
    else
        log_error "❌ tyk namespace does not exist"
        return 1
    fi
    
    # Check Helm repo
    if helm repo list | grep -q "tyk-helm"; then
        log_success "✅ Tyk Helm repository configured"
    else
        log_error "❌ Tyk Helm repository not configured"
        return 1
    fi
    
    log_success "All prerequisites verified successfully!"
}

# Main execution
main() {
    echo "=========================================="
    echo "Tyk Control Plane - Cluster Prerequisites"
    echo "=========================================="
    echo ""
    
    check_cluster_access
    echo ""
    
    install_cert_manager
    echo ""
    
    install_tyk_operator_crds
    echo ""
    
    setup_helm_repos
    echo ""
    
    create_tyk_namespace
    echo ""
    
    verify_prerequisites
    echo ""
    
    log_success "🎉 Cluster prerequisites setup complete!"
    log_info "You can now proceed to deploy Tyk Control Plane"
}

# Run main function
main "$@"