#!/bin/bash
set -e

echo "🚀 Deploying Tyk Control Plane using Official Helm Chart"
echo "======================================================="

# Make scripts executable
chmod +x scripts/extract-infrastructure-secrets.sh
chmod +x scripts/setup-helm-repo.sh

# Step 1: Extract infrastructure secrets
echo "📋 Step 1: Extracting infrastructure connection details..."
./scripts/extract-infrastructure-secrets.sh

# Step 2: Setup Helm repository
echo "📦 Step 2: Setting up Tyk Helm repository..."
./scripts/setup-helm-repo.sh

# Step 3: Source environment variables
echo "🔐 Step 3: Loading environment variables..."
if [[ ! -f "kubernetes/tyk-control-plane/.env" ]]; then
    echo "❌ Error: .env file not found at kubernetes/tyk-control-plane/.env"
    exit 1
fi

if [[ ! -f "kubernetes/tyk-control-plane/infrastructure.env" ]]; then
    echo "❌ Error: infrastructure.env file not found. Run extract-infrastructure-secrets.sh first"
    exit 1
fi

source kubernetes/tyk-control-plane/.env
source kubernetes/tyk-control-plane/infrastructure.env

# Step 4: Create namespace
echo "🏗️  Step 4: Creating Kubernetes namespace..."
kubectl apply -f kubernetes/tyk-control-plane/00-namespace.yaml

# Step 5: Generate secrets
echo "🔑 Step 5: Generating API, Admin, and MDCB security secrets..."
API_SECRET=$(openssl rand -hex 32)
ADMIN_SECRET=$(openssl rand -hex 32)
MDCB_SECURITY_SECRET=$(openssl rand -base64 32)

# Step 6: Create values.yaml with real values
echo "⚙️  Step 6: Configuring Helm values..."
cp kubernetes/tyk-control-plane/values.yaml kubernetes/tyk-control-plane/values-configured.yaml

# URL-encode the PostgreSQL password for connection strings
POSTGRES_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$POSTGRES_PASSWORD', safe=''))")

# Export variables for envsubst
export POSTGRES_HOST POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD POSTGRES_PASSWORD_ENCODED
export REDIS_HOST REDIS_PORT REDIS_PASSWORD
export DASHBOARD_LICENSE MDCB_LICENSE PORTAL_LICENSE
export API_SECRET ADMIN_SECRET MDCB_SECURITY_SECRET
export ADMIN_FIRST_NAME ADMIN_LAST_NAME ADMIN_EMAIL ADMIN_PASSWORD

# Use envsubst to replace placeholders (handles special characters safely)
envsubst < kubernetes/tyk-control-plane/values-configured.yaml > kubernetes/tyk-control-plane/values-final.yaml
mv kubernetes/tyk-control-plane/values-final.yaml kubernetes/tyk-control-plane/values-configured.yaml

echo "✅ Configuration complete!"

# Step 7: Deploy Tyk Control Plane
echo "🚀 Step 7: Deploying Tyk Control Plane..."
helm install tyk-cp tyk-helm/tyk-control-plane \
    --namespace tyk \
    --values kubernetes/tyk-control-plane/values-configured.yaml \
    --wait \
    --timeout 10m

# Step 8: Verify deployment
echo "🔍 Step 8: Verifying deployment..."
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all -n tyk --timeout=300s

echo ""
echo "📊 Deployment Status:"
echo "===================="
kubectl get pods -n tyk
echo ""
kubectl get services -n tyk
echo ""

# Step 9: Provide access instructions
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "🔒 All services are deployed with ClusterIP (secure, no internet exposure)"
echo ""
echo "📡 To access the services, use port forwarding:"
echo ""
echo "Tyk Dashboard:"
echo "  kubectl port-forward -n tyk svc/tyk-cp-tyk-dashboard 3000:3000"
echo "  Then access: http://localhost:3000"
echo ""
echo "Developer Portal:" 
echo "  kubectl port-forward -n tyk svc/tyk-cp-tyk-dev-portal 3001:3001"
echo "  Then access: http://localhost:3001"
echo ""
echo "Tyk Gateway:"
echo "  kubectl port-forward -n tyk svc/tyk-cp-tyk-gateway 8080:8080"
echo "  Then access: http://localhost:8080"
echo ""
echo "🔑 Admin Credentials:"
echo "  Email: $ADMIN_EMAIL"
echo "  Password: $ADMIN_PASSWORD"
echo ""
echo "✅ All pods should be running. Check with: kubectl get pods -n tyk"