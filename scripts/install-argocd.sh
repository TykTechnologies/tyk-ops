#!/bin/bash

# ArgoCD Installation Script for Tyk Control Plane GitOps
# This script installs ArgoCD on any Kubernetes cluster
# Run this after infrastructure provisioning and secret extraction

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

# Configuration
ARGOCD_VERSION="v2.12.4"
ARGOCD_NAMESPACE="argocd"
ARGOCD_REPO_URL="https://github.com/TykTechnologies/tyk-ops"

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

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD $ARGOCD_VERSION..."
    
    # Check if ArgoCD is already installed
    if kubectl get namespace "$ARGOCD_NAMESPACE" &> /dev/null; then
        log_warning "ArgoCD namespace already exists, checking deployment..."
        if kubectl get deployment -n "$ARGOCD_NAMESPACE" argocd-server &> /dev/null; then
            log_success "ArgoCD is already installed"
            return 0
        fi
    fi
    
    # Create namespace
    log_info "Creating ArgoCD namespace..."
    kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    log_info "Installing ArgoCD manifests..."
    kubectl apply -n "$ARGOCD_NAMESPACE" -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    log_info "Checking ArgoCD server deployment..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n "$ARGOCD_NAMESPACE"
    log_info "Checking ArgoCD application controller statefulset..."
    # Wait for StatefulSet to be ready (simpler approach)
    local retries=0
    local max_retries=60
    while [ $retries -lt $max_retries ]; do
        if kubectl get statefulset argocd-application-controller -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.readyReplicas}' | grep -q "1"; then
            log_info "ArgoCD application controller is ready"
            break
        fi
        log_info "Waiting for ArgoCD application controller... (attempt $((retries+1))/$max_retries)"
        sleep 10
        ((retries++))
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "ArgoCD application controller failed to become ready within timeout"
        return 1
    fi
    log_info "Checking ArgoCD repo server deployment..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE"
    log_info "Checking ArgoCD redis deployment..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-redis -n "$ARGOCD_NAMESPACE"
    
    log_success "ArgoCD installed and ready"
}

# Configure ArgoCD repository
configure_argocd_repo() {
    log_info "Configuring ArgoCD repository access..."
    
    # Wait for ArgoCD to be fully ready
    log_info "Waiting for ArgoCD server to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n "$ARGOCD_NAMESPACE" --timeout=300s
    
    # Create repository secret (public repo, no auth needed)
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tyk-ops-repo
  namespace: $ARGOCD_NAMESPACE
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: $ARGOCD_REPO_URL
EOF
    
    log_success "Repository configured"
}

# Get ArgoCD admin password
get_argocd_password() {
    log_info "Retrieving ArgoCD admin password..."
    
    # Wait for initial admin secret to be created
    local retries=0
    local max_retries=30
    
    while ! kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" &> /dev/null; do
        if [ $retries -ge $max_retries ]; then
            log_error "ArgoCD initial admin secret not found after $max_retries attempts"
            return 1
        fi
        log_info "Waiting for ArgoCD initial admin secret... (attempt $((retries+1))/$max_retries)"
        sleep 10
        ((retries++))
    done
    
    local admin_password=$(kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
    
    if [ -n "$admin_password" ]; then
        log_success "ArgoCD admin password retrieved"
        echo ""
        echo "=========================================="
        echo "ArgoCD Access Information"
        echo "=========================================="
        echo "Username: admin"
        echo "Password: $admin_password"
        echo ""
        echo "To access ArgoCD UI, run:"
        echo "kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
        echo "Then open: https://localhost:8080"
        echo "=========================================="
        echo ""
    else
        log_error "Failed to retrieve ArgoCD admin password"
        return 1
    fi
}

# Setup ArgoCD CLI (optional)
setup_argocd_cli() {
    log_info "Setting up ArgoCD CLI access..."
    
    if ! command -v argocd &> /dev/null; then
        log_warning "ArgoCD CLI not found. You can install it from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
        return 0
    fi
    
    # Port forward in background for CLI setup
    log_info "Setting up port forward for ArgoCD CLI..."
    kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" 8080:443 &
    local port_forward_pid=$!
    
    # Wait for port forward to be ready
    sleep 5
    
    # Get admin password
    local admin_password=$(kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data.password}' | base64 --decode)
    
    # Login to ArgoCD
    log_info "Logging into ArgoCD CLI..."
    argocd login localhost:8080 --username admin --password "$admin_password" --insecure
    
    # Kill port forward
    kill $port_forward_pid 2>/dev/null || true
    
    log_success "ArgoCD CLI configured"
}
# Verify installation
verify_installation() {
    log_info "Verifying ArgoCD installation..."
    log_info "Checking ArgoCD component health..."
    
    # Check ArgoCD components
    if kubectl get deployment -n "$ARGOCD_NAMESPACE" argocd-server &> /dev/null; then
        local server_ready=$(kubectl get deployment -n "$ARGOCD_NAMESPACE" argocd-server -o jsonpath='{.status.readyReplicas}')
        if [[ "$server_ready" -gt 0 ]]; then
            log_success "✅ ArgoCD server is running ($server_ready replicas ready)"
        else
            log_error "❌ ArgoCD server is not ready"
            return 1
        fi
    else
        log_error "❌ ArgoCD server is not installed"
        return 1
    fi
    
    # Check ArgoCD application controller (StatefulSet in v2.12.4+)
    if kubectl get statefulset -n "$ARGOCD_NAMESPACE" argocd-application-controller &> /dev/null; then
        local controller_ready=$(kubectl get statefulset -n "$ARGOCD_NAMESPACE" argocd-application-controller -o jsonpath='{.status.readyReplicas}')
        if [[ "$controller_ready" -gt 0 ]]; then
            log_success "✅ ArgoCD application controller is running ($controller_ready replicas ready)"
        else
            log_error "❌ ArgoCD application controller is not ready"
            return 1
        fi
    else
        log_error "❌ ArgoCD application controller is not installed"
        return 1
    fi
    
    # Check repository configuration
    if kubectl get secret tyk-ops-repo -n "$ARGOCD_NAMESPACE" &> /dev/null; then
        log_success "✅ Tyk repository configured"
    else
        log_error "❌ Tyk repository not configured"
        return 1
    fi
    
    log_success "All ArgoCD components verified successfully!"
}

# Main execution
main() {
    echo "=========================================="
    echo "ArgoCD Installation for Tyk Control Plane"
    echo "=========================================="
    echo ""
    
    check_cluster_access
    echo ""
    
    install_argocd
    echo ""
    
    configure_argocd_repo
    echo ""
    
    get_argocd_password
    echo ""
    
    setup_argocd_cli
    echo ""
    
    verify_installation
    echo ""
    
    log_success "🎉 ArgoCD installation complete!"
    log_info "Next steps:"
    log_info "1. Run './scripts/setup-gitops.sh' to deploy Tyk applications"
    log_info "2. Access ArgoCD UI with the credentials shown above"
    log_info "3. Monitor application deployment in ArgoCD dashboard"
}

# Run main function
main "$@"
    