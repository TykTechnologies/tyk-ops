# Makefile for Tyk Control Plane Operations
# This file contains commands to manage traditional and GitOps deployments

.PHONY: help setup-prerequisites deploy helm-deploy fresh-deploy status install-argocd setup-gitops setup-tyk-applications gitops-deploy gitops-status

# Load environment variables if they exist
-include kubernetes/tyk-control-plane/infrastructure.env

help: ## Show this help message
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup-prerequisites: ## Setup cluster prerequisites (cert-manager, namespaces, helm repos)
	@echo "Setting up cluster prerequisites..."
	@chmod +x scripts/setup-cluster-prerequisites.sh
	@./scripts/setup-cluster-prerequisites.sh && echo "✓ Prerequisites setup completed" || echo "✗ Prerequisites setup failed"

deploy: setup-prerequisites ## Deploy Tyk Control Plane (requires prerequisites)
	@echo "Deploying Tyk Control Plane..."
	@chmod +x scripts/deploy-tyk-control-plane.sh
	@./scripts/deploy-tyk-control-plane.sh && echo "✓ Deployment completed" || echo "✗ Deployment failed"

helm-deploy: ## Complete Helm-based deployment (infrastructure + prerequisites + tyk)
	@echo "Starting Helm-based deployment..."
	@echo "Step 1: Deploying infrastructure..."
	@cd terraform/deployments/control-plane/azure && terraform apply -auto-approve -var-file="examples/dev.tfvars"
	@echo "Step 2: Extracting infrastructure secrets..."
	@./scripts/extract-infrastructure-secrets.sh
	@echo "Step 3: Setting up cluster prerequisites..."
	@make setup-prerequisites
	@echo "Step 4: Deploying Tyk Control Plane..."
	@make deploy
	@echo "✓ Helm deployment completed!"

fresh-deploy: helm-deploy ## Alias for helm-deploy (backward compatibility)

status: ## Check deployment status
	@echo "Checking deployment status..."
	@echo ""
	@echo "=== Pods Status ==="
	@kubectl get pods -n tyk 2>/dev/null || echo "✗ No pods found (namespace may not exist)"
	@echo ""
	@echo "=== Services Status ==="
	@kubectl get services -n tyk 2>/dev/null || echo "✗ No services found (namespace may not exist)"

# GitOps Commands
install-argocd: ## Install ArgoCD on the cluster
	@echo "Installing ArgoCD..."
	@chmod +x scripts/install-argocd.sh
	@./scripts/install-argocd.sh && echo "✓ ArgoCD installation completed" || echo "✗ ArgoCD installation failed"

setup-gitops: ## Setup GitOps (create secrets and deploy ArgoCD applications)
	@echo "Setting up GitOps deployment..."
	@chmod +x scripts/setup-gitops.sh
	@./scripts/setup-gitops.sh && echo "✓ GitOps setup completed" || echo "✗ GitOps setup failed"

setup-tyk-applications: setup-gitops ## Setup Tyk applications in ArgoCD (alias for setup-gitops)

gitops-deploy: ## Complete GitOps deployment (infrastructure + ArgoCD + applications)
	@echo "Starting GitOps deployment..."
	@echo "Step 1: Deploying infrastructure..."
	@cd terraform/deployments/control-plane/azure && terraform apply -auto-approve -var-file="examples/dev.tfvars"
	@echo "Step 2: Extracting infrastructure secrets..."
	@./scripts/extract-infrastructure-secrets.sh
	@echo "Step 3: Installing ArgoCD..."
	@make install-argocd
	@echo "Step 4: Setting up GitOps..."
	@make setup-gitops
	@echo "✓ GitOps deployment completed!"

gitops-status: ## Check GitOps deployment status
	@echo "Checking GitOps deployment status..."
	@echo ""
	@echo "=== ArgoCD Applications ==="
	@kubectl get applications -n argocd 2>/dev/null || echo "✗ No ArgoCD applications found"
	@echo ""
	@echo "=== Tyk Pods Status ==="
	@kubectl get pods -n tyk 2>/dev/null || echo "✗ No Tyk pods found (may still be deploying)"
	@echo ""
	@echo "=== Tyk Services Status ==="
	@kubectl get services -n tyk 2>/dev/null || echo "✗ No Tyk services found (may still be deploying)"

# Monitoring commands
logs-mdcb: ## Show MDCB logs
	@kubectl logs -n tyk -l app.kubernetes.io/name=tyk-mdcb --tail=50

logs-dashboard: ## Show Dashboard logs
	@kubectl logs -n tyk -l app.kubernetes.io/name=tyk-dashboard --tail=50

logs-portal: ## Show Portal logs
	@kubectl logs -n tyk -l app.kubernetes.io/name=tyk-dev-portal --tail=50

logs-all: ## Show logs from all Tyk components
	@echo "=== MDCB Logs ==="
	@make logs-mdcb || echo "✗ No MDCB pods found"
	@echo ""
	@echo "=== Dashboard Logs ==="
	@make logs-dashboard || echo "✗ No Dashboard pods found"
	@echo ""
	@echo "=== Portal Logs ==="
	@make logs-portal || echo "✗ No Portal pods found"