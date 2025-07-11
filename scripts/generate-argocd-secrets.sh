#!/bin/bash
set -e

echo "=== Generating Kubernetes Secrets for ArgoCD Deployment ==="

# Source environment files
if [ ! -f kubernetes/tyk-control-plane/.env ]; then
    echo "❌ Error: kubernetes/tyk-control-plane/.env file not found"
    exit 1
fi

if [ ! -f kubernetes/tyk-control-plane/infrastructure.env ]; then
    echo "❌ Error: kubernetes/tyk-control-plane/infrastructure.env file not found"
    echo "Please run ./scripts/extract-infrastructure-secrets.sh first"
    exit 1
fi

source kubernetes/tyk-control-plane/.env
source kubernetes/tyk-control-plane/infrastructure.env

# Validate required variables from .env
if [ -z "$DASHBOARD_LICENSE" ] || [ -z "$MDCB_LICENSE" ] || [ -z "$PORTAL_LICENSE" ] || [ -z "$OPERATOR_LICENSE" ]; then
    echo "❌ Error: Missing required license variables in .env file"
    echo "Required: DASHBOARD_LICENSE, MDCB_LICENSE, PORTAL_LICENSE, OPERATOR_LICENSE"
    exit 1
fi

if [ -z "$ADMIN_FIRST_NAME" ] || [ -z "$ADMIN_LAST_NAME" ] || [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "❌ Error: Missing required admin user variables in .env file"
    echo "Required: ADMIN_FIRST_NAME, ADMIN_LAST_NAME, ADMIN_EMAIL, ADMIN_PASSWORD"
    exit 1
fi

# Validate required variables from infrastructure.env
if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ]; then
    echo "❌ Error: Missing required PostgreSQL variables in infrastructure.env file"
    echo "Required: POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB"
    exit 1
fi

if [ -z "$REDIS_HOST" ] || [ -z "$REDIS_PORT" ] || [ -z "$REDIS_PASSWORD" ]; then
    echo "❌ Error: Missing required Redis variables in infrastructure.env file"
    echo "Required: REDIS_HOST, REDIS_PORT, REDIS_PASSWORD"
    exit 1
fi

# Create namespace if it doesn't exist
kubectl create namespace tyk --dry-run=client -o yaml | kubectl apply -f -

# Generate API and Admin secrets if not provided or are placeholders
if [ -z "$API_SECRET" ] || [ "$API_SECRET" == "CHANGEME_GENERATE_RANDOM_STRING" ]; then
    API_SECRET=$(openssl rand -hex 32)
    echo "✅ Generated API_SECRET: $API_SECRET"
fi

if [ -z "$ADMIN_SECRET" ] || [ "$ADMIN_SECRET" == "CHANGEME_GENERATE_RANDOM_STRING" ]; then
    ADMIN_SECRET=$(openssl rand -hex 32)
    echo "✅ Generated ADMIN_SECRET: $ADMIN_SECRET"
fi

# Generate database connection strings
POSTGRES_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$POSTGRES_PASSWORD', safe=''))")
DEV_PORTAL_DB_CONNECTION_STRING="host=$POSTGRES_HOST port=5432 dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD_ENCODED sslmode=require"
POSTGRES_CONNECTION_STRING="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD_ENCODED@$POSTGRES_HOST:5432/$POSTGRES_DB?sslmode=require"

# Create comprehensive secret for all Tyk components
echo "Creating tyk-control-plane-secret..."
kubectl create secret generic tyk-control-plane-secret \
    --namespace=tyk \
    --from-literal=APISecret="$API_SECRET" \
    --from-literal=AdminSecret="$ADMIN_SECRET" \
    --from-literal=securitySecret="$API_SECRET" \
    --from-literal=DashLicense="$DASHBOARD_LICENSE" \
    --from-literal=MDCBLicense="$MDCB_LICENSE" \
    --from-literal=DevPortalLicense="$PORTAL_LICENSE" \
    --from-literal=DevPortalDatabaseConnectionString="$DEV_PORTAL_DB_CONNECTION_STRING" \
    --from-literal=OperatorLicense="$OPERATOR_LICENSE" \
    --from-literal=adminUserFirstName="$ADMIN_FIRST_NAME" \
    --from-literal=adminUserLastName="$ADMIN_LAST_NAME" \
    --from-literal=adminUserEmail="$ADMIN_EMAIL" \
    --from-literal=adminUserPassword="$ADMIN_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create complete Redis address for Tyk components
REDIS_ADDR="$REDIS_HOST:$REDIS_PORT"

# Create infrastructure secrets
echo "Creating tyk-infrastructure-secret..."
kubectl create secret generic tyk-infrastructure-secret \
    --namespace=tyk \
    --from-literal=postgresHost="$POSTGRES_HOST" \
    --from-literal=postgresUser="$POSTGRES_USER" \
    --from-literal=postgresPassword="$POSTGRES_PASSWORD" \
    --from-literal=postgresDatabase="$POSTGRES_DB" \
    --from-literal=postgresConnectionString="$POSTGRES_CONNECTION_STRING" \
    --from-literal=redisHost="$REDIS_HOST" \
    --from-literal=redisPort="$REDIS_PORT" \
    --from-literal=redisPassword="$REDIS_PASSWORD" \
    --from-literal=redisAddr="$REDIS_ADDR" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create Tyk Operator configuration secret
echo "Creating tyk-operator-conf secret..."
kubectl create secret generic tyk-operator-conf \
    --namespace=tyk \
    --from-literal=TYK_MODE=ce \
    --from-literal=TYK_URL=http://gateway-tyk-cp-tyk-gateway.tyk.svc.cluster.local:8080 \
    --from-literal=TYK_AUTH="$API_SECRET" \
    --from-literal=TYK_ORG=1 \
    --dry-run=client -o yaml | kubectl apply -f -

# Create Dashboard-specific secret with resolved connection strings (for backward compatibility)
echo "Creating secrets-tyk-cp-tyk-dashboard secret..."
kubectl create secret generic secrets-tyk-cp-tyk-dashboard \
    --namespace=tyk \
    --from-literal=pgConnectionString="$DEV_PORTAL_DB_CONNECTION_STRING" \
    --from-literal=mongoURL="mongodb://mongo.tyk.svc:27017/tyk_analytics" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Kubernetes secrets created successfully!"
echo ""
echo "📋 Secrets created:"
echo "   - tyk-control-plane-secret (licenses, admin user, API/Admin secrets, DB connection)"
echo "   - tyk-infrastructure-secret (database and Redis connections)"
echo "   - tyk-operator-conf (operator configuration)"
echo "   - secrets-tyk-cp-tyk-dashboard (Dashboard-specific DB connections)"
echo ""
echo "🔍 Verify secrets:"
echo "   kubectl get secrets -n tyk"
echo "   kubectl describe secret tyk-control-plane-secret -n tyk"
echo "   kubectl describe secret tyk-infrastructure-secret -n tyk"
echo "   kubectl describe secret tyk-operator-conf -n tyk"
echo "   kubectl describe secret secrets-tyk-cp-tyk-dashboard -n tyk"
echo ""
echo "🚀 Ready to deploy Tyk Control Plane via ArgoCD!"