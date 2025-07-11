#!/bin/bash

# GitOps Setup Script for Tyk Control Plane
# This script creates required secrets and deploys the ArgoCD root application
# Run this after ArgoCD installation and infrastructure secret extraction

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster. Please check your kubeconfig"
        exit 1
    fi
    
    # Check ArgoCD installation
    if ! kubectl get namespace argocd &> /dev/null; then
        log_error "ArgoCD namespace not found. Please run './scripts/install-argocd.sh' first"
        exit 1
    fi
    
    # Check environment files
    if [[ ! -f "kubernetes/tyk-control-plane/.env" ]]; then
        log_error ".env file not found at kubernetes/tyk-control-plane/.env"
        exit 1
    fi
    
    if [[ ! -f "kubernetes/tyk-control-plane/infrastructure.env" ]]; then
        log_error "infrastructure.env file not found. Run './scripts/extract-infrastructure-secrets.sh' first"
        exit 1
    fi
    
    log_success "All prerequisites verified"
}

# Load environment variables
load_environment() {
    log_info "Loading environment variables..."
    
    source kubernetes/tyk-control-plane/.env
    source kubernetes/tyk-control-plane/infrastructure.env
    
    # Generate security secrets
    API_SECRET=$(openssl rand -hex 32)
    ADMIN_SECRET=$(openssl rand -hex 32)
    MDCB_SECURITY_SECRET=$(openssl rand -base64 32)
    
    # URL-encode the PostgreSQL password for connection strings
    POSTGRES_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$POSTGRES_PASSWORD', safe=''))")
    
    # Export variables for secret creation
    export POSTGRES_HOST POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD POSTGRES_PASSWORD_ENCODED
    export REDIS_HOST REDIS_PORT REDIS_PASSWORD
    export DASHBOARD_LICENSE MDCB_LICENSE PORTAL_LICENSE OPERATOR_LICENSE
    export API_SECRET ADMIN_SECRET MDCB_SECURITY_SECRET
    export ADMIN_FIRST_NAME ADMIN_LAST_NAME ADMIN_EMAIL ADMIN_PASSWORD
    
    log_success "Environment variables loaded and secrets generated"
}

# Create Kubernetes secrets
create_secrets() {
    log_info "Creating Kubernetes secrets..."
    
    # Use the dedicated ArgoCD secrets generation script
    if [[ -f "./scripts/generate-argocd-secrets.sh" ]]; then
        log_info "Running ArgoCD secrets generation script..."
        ./scripts/generate-argocd-secrets.sh
        log_success "ArgoCD secrets created successfully"
    else
        log_error "ArgoCD secrets generation script not found at ./scripts/generate-argocd-secrets.sh"
        exit 1
    fi
}

# Deploy ArgoCD root application
deploy_root_application() {
    log_info "Deploying ArgoCD root application..."
    
    # Auto-detect Git repository URL
    local git_repo_url=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [[ -z "$git_repo_url" ]]; then
        log_error "Could not detect Git repository URL. Please ensure you're in a Git repository with a remote 'origin'."
        return 1
    fi
    
    # Convert SSH URLs to HTTPS URLs for ArgoCD compatibility
    if [[ "$git_repo_url" =~ ^git@github\.com:(.+)\.git$ ]]; then
        git_repo_url="https://github.com/${BASH_REMATCH[1]}.git"
        log_info "Converted SSH URL to HTTPS for ArgoCD compatibility"
    elif [[ "$git_repo_url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
        # Handle other Git providers (GitLab, Bitbucket, etc.)
        git_repo_url="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git"
        log_info "Converted SSH URL to HTTPS for ArgoCD compatibility"
    fi
    
    log_info "Using Git repository: $git_repo_url"
    
    # Update all ArgoCD applications to use the detected Git repository
    log_info "Updating ArgoCD applications to use your Git repository..."
    
    # Create temporary directory for updated manifests
    local temp_dir="/tmp/gitops-temp"
    mkdir -p "$temp_dir/applications"
    
    # Update all application manifests with correct repo URL
    for app_file in gitops/applications/*.yaml; do
        local app_name=$(basename "$app_file")
        sed "s|repoURL: https://github.com/TykTechnologies/tyk-ops|repoURL: $git_repo_url|g" \
            "$app_file" > "$temp_dir/applications/$app_name"
    done
    
    # Verify Git repository is accessible
    if ! git ls-remote --exit-code --heads origin main &> /dev/null; then
        log_warning "Could not access remote Git repository"
        log_info "Please ensure your fork is accessible and you have the correct permissions"
        log_info "ArgoCD needs to pull manifests from the remote repository"
    fi
    
    # Apply the root application with correct repo URL
    kubectl apply -f "$temp_dir/applications/root-app.yaml"
    
    # Clean up temporary files
    rm -rf "$temp_dir"
    
    # Wait for the application to be created (not available, just created)
    log_info "Waiting for ArgoCD application to be created..."
    local retries=0
    local max_retries=12
    
    while ! kubectl get application tyk-control-plane-apps -n argocd &> /dev/null; do
        if [ $retries -ge $max_retries ]; then
            log_error "Application not created after $max_retries attempts"
            return 1
        fi
        log_info "Waiting for application to be created... (attempt $((retries+1))/$max_retries)"
        sleep 5
        ((retries++))
    done
    
    log_success "Root application deployed successfully"
    log_info "ArgoCD will sync from repository: $git_repo_url"
}

# Monitor deployment
monitor_deployment() {
    log_info "Monitoring ArgoCD application deployment..."
    
    # Show ArgoCD applications
    echo ""
    log_info "ArgoCD Applications:"
    kubectl get applications -n argocd
    
    echo ""
    log_info "To monitor the deployment progress:"
    log_info "1. Access ArgoCD UI:"
    log_info "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    log_info "   Then open: https://localhost:8080"
    echo ""
    log_info "2. Check application sync status:"
    log_info "   kubectl get applications -n argocd -w"
    echo ""
    log_info "3. Check Tyk pods (may take a few minutes):"
    log_info "   kubectl get pods -n tyk -w"
    echo ""
}

# Verify deployment
verify_deployment() {
    log_info "Waiting for applications to sync..."
    
    # Wait for applications to appear
    local retries=0
    local max_retries=12
    
    while ! kubectl get application tyk-prerequisites -n argocd &> /dev/null; do
        if [ $retries -ge $max_retries ]; then
            log_warning "Applications not created yet. Check ArgoCD UI for details."
            return 0
        fi
        log_info "Waiting for applications to be created... (attempt $((retries+1))/$max_retries)"
        sleep 10
        ((retries++))
    done
    
    log_success "ArgoCD applications are being deployed"
    log_info "Use 'kubectl get applications -n argocd -w' to monitor progress"
}

# Provide access instructions
provide_access_instructions() {
    echo ""
    echo "=========================================="
    echo "GitOps Deployment Complete!"
    echo "=========================================="
    echo ""
    log_success "ArgoCD is now managing your Tyk Control Plane deployment"
    echo ""
    echo "🔍 Monitor deployment:"
    echo "  kubectl get applications -n argocd -w"
    echo "  kubectl get pods -n tyk -w"
    echo ""
    echo "🌐 Access ArgoCD UI:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Then open: https://localhost:8080"
    echo ""
    echo "📡 Once deployed, access Tyk services:"
    echo "  Tyk Dashboard:"
    echo "    kubectl port-forward -n tyk svc/tyk-cp-tyk-dashboard 3000:3000"
    echo "    Then access: http://localhost:3000"
    echo ""
    echo "  Developer Portal:"
    echo "    kubectl port-forward -n tyk svc/tyk-cp-tyk-dev-portal 3001:3001"
    echo "    Then access: http://localhost:3001"
    echo ""
    echo "  Tyk Gateway:"
    echo "    kubectl port-forward -n tyk svc/tyk-cp-tyk-gateway 8080:8080"
    echo "    Then access: http://localhost:8080"
    echo ""
    echo "🔑 Admin Credentials:"
    echo "  Email: $ADMIN_EMAIL"
    echo "  Password: $ADMIN_PASSWORD"
    echo ""
    echo "⚙️ GitOps Management:"
    echo "  - All changes should be made via Git commits"
    echo "  - ArgoCD will automatically sync changes from the repository"
    echo "  - Manual kubectl changes may be overwritten"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "Tyk Control Plane GitOps Setup"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    echo ""
    
    load_environment
    echo ""
    
    create_secrets
    echo ""
    
    deploy_root_application
    echo ""
    
    monitor_deployment
    echo ""
    
    verify_deployment
    echo ""
    
    provide_access_instructions
    echo ""
    
    log_success "🎉 GitOps setup complete!"
    log_info "Your Tyk Control Plane is now managed by ArgoCD"
}

# Run main function
main "$@"