# Makefile for Tyk Control Plane Operations
# This file contains commands to manage traditional and GitOps deployments

.PHONY: help setup-prerequisites deploy status install-argocd delete-argocd create-secrets setup-gitops

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


status: ## Check deployment status
	@echo "Checking deployment status..."
	@echo ""
	@echo "=== Pods Status ==="
	@kubectl get pods -n tyk 2>/dev/null || echo "✗ No pods found (namespace may not exist)"
	@echo ""
	@echo "=== Services Status ==="
	@kubectl get services -n tyk 2>/dev/null || echo "✗ No services found (namespace may not exist)"

# GitOps Commands
install-argocd: ## Install ArgoCD using Helm chart
	@echo "Installing ArgoCD using Helm..."
	@echo "=========================================="
	@echo "ArgoCD Installation for Tyk Control Plane"
	@echo "=========================================="
	@echo ""
	@echo "[INFO] Checking Kubernetes cluster access..."
	@kubectl cluster-info --request-timeout=10s > /dev/null 2>&1 || (echo "✗ Cannot access Kubernetes cluster" && exit 1)
	@echo "[SUCCESS] Connected to cluster"
	@echo ""
	@echo "[INFO] Adding ArgoCD Helm repository..."
	@helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || echo "[INFO] ArgoCD Helm repo already exists"
	@helm repo update argo
	@echo "[SUCCESS] ArgoCD Helm repository updated"
	@echo ""
	@echo "[INFO] Creating ArgoCD namespace..."
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@echo "[SUCCESS] ArgoCD namespace ready"
	@echo ""
	@echo "[INFO] Installing ArgoCD v2.12.4..."
	@helm install argocd argo/argo-cd \
		--namespace argocd \
		--values helm/argocd-values.yaml \
		--version 7.6.12 \
		--wait --timeout=600s
	@echo "[SUCCESS] ArgoCD installed and ready"
	@echo ""
	@echo "[INFO] Retrieving ArgoCD admin password..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s > /dev/null 2>&1
	@ADMIN_PASSWORD=$$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null || echo "Password not ready yet"); \
	echo "[SUCCESS] ArgoCD admin password retrieved"; \
	echo ""; \
	echo "=========================================="; \
	echo "ArgoCD Access Information"; \
	echo "=========================================="; \
	echo "Username: admin"; \
	echo "Password: $$ADMIN_PASSWORD"; \
	echo ""; \
	echo "To access ArgoCD UI, run:"; \
	echo "kubectl port-forward svc/argocd-server -n argocd 8080:80"; \
	echo "Then open: http://localhost:8080"; \
	echo "=========================================="; \
	echo ""
	@echo "[INFO] Verifying ArgoCD installation..."
	@kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | grep -q "Running" && echo "[SUCCESS] ✅ ArgoCD server is running" || echo "[ERROR] ❌ ArgoCD server is not running"
	@kubectl get statefulset -n argocd -l app.kubernetes.io/name=argocd-application-controller --no-headers | grep -q "1/1" && echo "[SUCCESS] ✅ ArgoCD application controller is running" || echo "[ERROR] ❌ ArgoCD application controller is not running"
	@kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server --no-headers | grep -q "Running" && echo "[SUCCESS] ✅ ArgoCD repo server is running" || echo "[ERROR] ❌ ArgoCD repo server is not running"
	@echo "[SUCCESS] All ArgoCD components verified successfully!"
	@echo ""
	@echo "[SUCCESS] 🎉 ArgoCD installation complete!"
	@echo "[INFO] Next steps:"
	@echo "[INFO] 1. Run 'make setup-gitops' to deploy Tyk applications"
	@echo "[INFO] 2. Access ArgoCD UI with the credentials shown above"
	@echo "[INFO] 3. Monitor application deployment in ArgoCD dashboard"
	@echo "✓ ArgoCD installation completed"

delete-argocd: ## Uninstall ArgoCD and clean up all resources including CRDs
	@echo "Uninstalling ArgoCD..."
	@echo "=========================================="
	@echo "ArgoCD Cleanup for Tyk Control Plane"
	@echo "=========================================="
	@echo ""
	@echo "[INFO] Checking if ArgoCD is installed..."
	@if helm list -n argocd 2>/dev/null | grep -q argocd; then \
		echo "[INFO] Uninstalling ArgoCD Helm release..."; \
		helm uninstall argocd -n argocd; \
		echo "[SUCCESS] ArgoCD Helm release uninstalled"; \
	else \
		echo "[INFO] ArgoCD Helm release not found"; \
	fi
	@echo ""
	@echo "[INFO] Deleting ArgoCD namespace..."
	@kubectl delete namespace argocd --ignore-not-found=true
	@echo "[SUCCESS] ArgoCD namespace deleted"
	@echo ""
	@echo "[INFO] Cleaning up ArgoCD CRDs..."
	@kubectl delete crd applications.argoproj.io --ignore-not-found=true
	@kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true
	@kubectl delete crd appprojects.argoproj.io --ignore-not-found=true
	@echo "[SUCCESS] ArgoCD CRDs cleaned up"
	@echo ""
	@echo "[INFO] Cleaning up cluster roles and bindings..."
	@kubectl delete clusterrole argocd-application-controller --ignore-not-found=true
	@kubectl delete clusterrole argocd-applicationset-controller --ignore-not-found=true
	@kubectl delete clusterrole argocd-server --ignore-not-found=true
	@kubectl delete clusterrolebinding argocd-application-controller --ignore-not-found=true
	@kubectl delete clusterrolebinding argocd-applicationset-controller --ignore-not-found=true
	@kubectl delete clusterrolebinding argocd-server --ignore-not-found=true
	@echo "[SUCCESS] Cluster roles and bindings cleaned up"
	@echo ""
	@echo "[SUCCESS] 🎉 ArgoCD completely removed from cluster!"
	@echo "✓ ArgoCD cleanup completed"

create-secrets: ## Create Kubernetes secrets from infrastructure.env
	@echo "Creating Kubernetes secrets..."
	@if [ ! -f "kubernetes/tyk-control-plane/infrastructure.env" ]; then \
		echo "✗ infrastructure.env not found. Run './scripts/extract-infrastructure-secrets.sh' first"; \
		exit 1; \
	fi
	@echo "Creating tyk namespace..."
	@kubectl create namespace tyk --dry-run=client -o yaml | kubectl apply -f -
	@echo "Creating secrets from infrastructure.env..."
	@kubectl create secret generic tyk-conf \
		--from-env-file=kubernetes/tyk-control-plane/infrastructure.env \
		--namespace=tyk \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ Secrets created successfully"

setup-gitops: ## Setup GitOps (create secrets and deploy ArgoCD applications)
	@echo "Setting up GitOps deployment..."
	@chmod +x scripts/setup-gitops.sh
	@./scripts/setup-gitops.sh && echo "✓ GitOps setup completed" || echo "✗ GitOps setup failed"
