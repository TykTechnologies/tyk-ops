# Tyk Control Plane Deployment Playbook

This playbook provides a step-by-step guide for deploying Tyk Control Plane from infrastructure provisioning to running API management platform.

## Overview

The deployment follows a systematic workflow:
1. **Infrastructure Deployment** - Provision Azure resources with Terraform
2. **Secret Extraction** - Convert Terraform outputs to Kubernetes configuration
3. **Cluster Prerequisites** - Setup required Kubernetes components
4. **Control Plane Deployment** - Deploy Tyk components with Helm
5. **Verification** - Validate deployment and obtain access details

## Prerequisites

### Required Tools
- **Azure CLI**: `az --version` (logged in with `az login`)
- **Terraform**: `terraform --version` (>= 1.0)
- **kubectl**: `kubectl version --client`
- **Helm**: `helm version` (>= 3.0)

### Required Permissions
- Azure subscription with ability to create resources
- Kubernetes cluster admin permissions (granted automatically)

## Step-by-Step Deployment

### Step 1: Deploy Infrastructure with Terraform

```bash
# Navigate to Terraform directory
cd terraform/deployments/control-plane/azure

# Initialize Terraform
terraform init

# Plan deployment (optional but recommended)
terraform plan -var-file="examples/dev.tfvars"

# Deploy infrastructure
terraform apply -var-file="examples/dev.tfvars"
```

**What this creates:**
- AKS cluster with 2 nodes
- PostgreSQL Flexible Server
- Redis Cache
- Virtual network and subnets
- All necessary Azure resources

### Step 2: Extract Infrastructure Secrets

```bash
# Extract Terraform outputs to environment file
./scripts/extract-infrastructure-secrets.sh
```

**What this does:**
1. Extracts Terraform outputs (database URLs, passwords, etc.)
2. Gets AKS credentials and configures kubectl
3. Creates `kubernetes/tyk-control-plane/infrastructure.env` with connection details

**Generated environment file contains:**
```bash
POSTGRES_HOST='your-postgres-server.postgres.database.azure.com'
POSTGRES_DB='tyk_analytics'
POSTGRES_USER='tyk_admin'
POSTGRES_PASSWORD='generated-password'
REDIS_HOST='your-redis-server.redis.cache.windows.net'
REDIS_PORT='6380'
REDIS_PASSWORD='redis-access-key'
```

### Step 3: Setup Kubernetes Prerequisites

```bash
# Install cluster prerequisites
./scripts/setup-cluster-prerequisites.sh
```

**What this installs:**
- **cert-manager**: For SSL certificate management
- **Tyk Operator CRDs**: Custom resource definitions (dynamically matched to operator version)
- **Helm repositories**: Tyk and other required charts
- **Namespace**: Creates `tyk` namespace

> **Dynamic Version Matching**: The script automatically detects the Tyk Operator version from `values.yaml` and installs matching CRDs to ensure compatibility.

### Step 4: Deploy Tyk Control Plane

```bash
# Deploy all Tyk components
./scripts/deploy-tyk-control-plane.sh
```

**What this deploys:**
- **Tyk Dashboard**: API management interface
- **Tyk Gateway**: API gateway for control plane
- **Tyk MDCB**: Multi-Data Center Bridge
- **Tyk Pump**: Analytics processor
- **Tyk Developer Portal**: API portal

**Secret management during deployment:**
1. Reads `infrastructure.env` and `.env` files
2. Creates Kubernetes secrets with connection details
3. Configures Helm values with secret references
4. Deploys Tyk components with proper configuration

### Step 5: Verify Deployment

```bash
# Check deployment status
make status

# Get all services
kubectl get services -n tyk

# Check pod status
kubectl get pods -n tyk
```

**Expected output:**
```
NAME                                   TYPE           EXTERNAL-IP      PORT
dashboard-svc-tyk-cp-tyk-dashboard     LoadBalancer   x.x.x.x          3000
gateway-svc-tyk-cp-tyk-gateway         LoadBalancer   x.x.x.x          8080
mdcb-svc-tyk-cp-tyk-mdcb               LoadBalancer   x.x.x.x          9091
```

## Secret Management Workflow

### 1. Terraform Outputs → Infrastructure Environment

The `extract-infrastructure-secrets.sh` script converts Terraform outputs to environment variables:

```bash
# Terraform outputs
terraform output -raw postgres_server_fqdn
terraform output -raw postgres_admin_password
terraform output -raw redis_primary_access_key

# Becomes environment variables
POSTGRES_HOST='server.postgres.database.azure.com'
POSTGRES_PASSWORD='generated-secure-password'
REDIS_PASSWORD='redis-access-key'
```

### 2. Environment Variables → Kubernetes Secrets

The `deploy-tyk-control-plane.sh` script creates Kubernetes secrets:

```bash
# Create database secret
kubectl create secret generic tyk-postgres-secret \
  --from-literal=host="$POSTGRES_HOST" \
  --from-literal=password="$POSTGRES

# Create Redis secret
kubectl create secret generic tyk-redis-secret \
  --from-literal=host="$REDIS_HOST" \
  --from-literal=password="$REDIS_PASSWORD" \
  --namespace=tyk
```

### 3. Kubernetes Secrets → Helm Values

The Helm charts reference the secrets via environment variables:

```yaml
# In values.yaml
env:
  - name: TYK_DB_CONNECTIONSTRING
    valueFrom:
      secretKeyRef:
        name: tyk-postgres-secret
        key: connectionstring
  - name: TYK_DB_REDISHOST  
    valueFrom:
      secretKeyRef:
        name: tyk-redis-secret
        key: host
```

## One-Command Deployment

For complete automation, use the Makefile:

```bash
# Deploy everything from scratch
make fresh-deploy
```

This single command:
1. Deploys infrastructure with Terraform
2. Extracts secrets automatically
3. Sets up prerequisites
4. Deploys Tyk Control Plane
5. Shows deployment status

## Access Information

### Tyk Dashboard
```bash
# Get Dashboard URL
DASHBOARD_IP=$(kubectl get service dashboard-svc-tyk-cp-tyk-dashboard -n tyk -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Dashboard URL: http://$DASHBOARD_IP:3000"

# Get admin credentials (from .env file)
cat kubernetes/tyk-control-plane/.env | grep TYK_ADMIN
```

### Tyk Gateway
```bash
# Get Gateway URL
GATEWAY_IP=$(kubectl get service gateway-svc-tyk-cp-tyk-gateway -n tyk -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Gateway URL: http://$GATEWAY_IP:8080"
echo "Health Check: http://$GATEWAY_IP:8080/hello"
```

### MDCB (for Data Plane connections)
```bash
# Get MDCB connection details
MDCB_IP=$(kubectl get service mdcb-svc-tyk-cp-tyk-mdcb -n tyk -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "MDCB RPC: $MDCB_IP:9091"
echo "MDCB HTTP: $MDCB_IP:8181"
```

## Connecting Data Planes

### 1. Get Organization Details
```bash
# Get organization ID and API key for data plane connections
ORG_ID=$(kubectl get secret tyk-operator-conf -n tyk -o jsonpath="{.data.TYK_ORG}" | base64 --decode)
API_KEY=$(kubectl get secret tyk-operator-conf -n tyk -o jsonpath="{.data.TYK_AUTH}" | base64 --decode)

echo "Organization ID: $ORG_ID"
echo "API Key: $API_KEY"
```

### 2. Data Plane Configuration
Use these connection details in your data plane deployment:

```yaml
# Data plane values
mdcb:
  enabled: true
  connectionString: "MDCB_IP:9091"
  orgId: "ORG_ID"
  key: "API_KEY"
```

## Troubleshooting

### Common Issues

#### 1. Tyk Operator CrashLoopBackOff
```bash
# Check Tyk Operator logs
kubectl logs -n tyk -l app.kubernetes.io/name=tyk-operator

# Common error: "no matches for kind TykOasApiDefinition"
# Fix: Re-run prerequisites setup to apply version-matched CRDs
./scripts/setup-cluster-prerequisites.sh

# Or manually apply correct CRDs (get version from values.yaml)
OPERATOR_VERSION=$(grep -A 2 "tyk-operator:" kubernetes/tyk-control-plane/values.yaml | grep "tag:" | awk '{print $2}' | tr -d '"')
kubectl apply -f "https://raw.githubusercontent.com/TykTechnologies/tyk-charts/refs/heads/main/tyk-operator-crds/crd-${OPERATOR_VERSION}.yaml"

# Restart operator deployment
kubectl rollout restart deployment tyk-cp-tyk-operator-controller-manager -n tyk

# Verify all required CRDs are installed
kubectl get crd | grep tyk
```

#### 2. MDCB CrashLoopBackOff
```bash
# Check MDCB logs
kubectl logs -n tyk -l app.kubernetes.io/name=tyk-mdcb

# Common causes:
# - Missing license in .env file
# - Invalid license format
# - Missing security secret
```

#### 3. Portal CrashLoopBackOff
```bash
# Check Portal logs
kubectl logs -n tyk -l app.kubernetes.io/name=tyk-dev-portal

# Common causes:
# - PostgreSQL connection issues
# - Special characters in password (use URL encoding)
# - Missing portal license
```

#### 4. Database Connection Issues
```bash
# Test PostgreSQL connection
kubectl run postgres-test --rm -it --image=postgres:13 -- \
  psql "postgresql://username:password@host:5432/database"

# Check connection string encoding
echo "postgres://user:$(python3 -c 'import urllib.parse; print(urllib.parse.quote("your-password"))')@host:5432/db"
```

### Monitoring Commands

```bash
# Check all pods
kubectl get pods -n tyk

# Get service endpoints
kubectl get services -n tyk

# View recent events
kubectl get events -n tyk --sort-by='.lastTimestamp'

# Check specific component logs
make logs-dashboard
make logs-mdcb
make logs-portal
```

## Customization

### Infrastructure Sizing
Edit the Terraform variables file:
```bash
# For development
terraform apply -var-file="examples/dev.tfvars"

# For staging
terraform apply -var-file="examples/staging.tfvars"

# For production
terraform apply -var-file="examples/prod.tfvars"
```

### Tyk Configuration
Modify the Helm values:
```bash
# Edit main configuration
vi kubernetes/tyk-control-plane/values.yaml

# Update licenses
vi kubernetes/tyk-control-plane/.env
```

### Custom Domains
To use custom domains instead of LoadBalancer IPs:
```bash
# Add ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Configure ingress in values.yaml
```

## Cleanup

### Remove Tyk Control Plane Only
```bash
helm uninstall tyk-cp -n tyk
kubectl delete namespace tyk
```

### Complete Cleanup (Infrastructure + Control Plane)
```bash
# Remove Tyk components
helm uninstall tyk-cp -n tyk

# Destroy Azure infrastructure
cd terraform/deployments/control-plane/azure
terraform destroy -var-file="examples/dev.tfvars"
```
