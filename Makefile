# Makefile for Tyk Control Plane Operations
# This file contains commands to manage and reset databases

.PHONY: help setup-prerequisites deploy fresh-deploy status

# Load environment variables
include kubernetes/tyk-control-plane/infrastructure.env

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

fresh-deploy: ## Complete fresh deployment (infrastructure + prerequisites + tyk)
	@echo "Starting fresh deployment..."
	@echo "Step 1: Deploying infrastructure..."
	@cd terraform/deployments/control-plane/azure && terraform apply -auto-approve -var-file="examples/dev.tfvars"
	@echo "Step 2: Extracting infrastructure secrets..."
	@./scripts/extract-infrastructure-secrets.sh
	@echo "Step 3: Setting up cluster prerequisites..."
	@make setup-prerequisites
	@echo "Step 4: Deploying Tyk Control Plane..."
	@make deploy
	@echo "✓ Fresh deployment completed!"

status: ## Check deployment status
	@echo "Checking deployment status..."
	@echo ""
	@echo "=== Pods Status ==="
	@kubectl get pods -n tyk 2>/dev/null || echo "✗ No pods found (namespace may not exist)"
	@echo ""
	@echo "=== Services Status ==="
	@kubectl get services -n tyk 2>/dev/null || echo "✗ No services found (namespace may not exist)"

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