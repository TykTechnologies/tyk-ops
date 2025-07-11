# Tyk Control Plane ArgoCD Deployment Plan

## Overview
This document outlines the complete plan for deploying Tyk Control Plane using ArgoCD with Helm chart version 3.x, targeting Tyk Dashboard and Gateway version 5.8.1.

## Current State Analysis

### Existing Configuration
- **Current Chart Version**: 3.0.0 (correct)
- **Current Tyk Versions**: Dashboard v5.8.1, Gateway v5.8.1 (correct version)
- **ArgoCD Application**: Configured with inline values instead of values file reference
- **Secrets**: ✅ All required secrets now exist in `.env` file

### Infrastructure Setup
- **Database/Redis**: Handled by Terraform outputs via `extract-infrastructure-secrets.sh`
- **Customer Secrets**: Stored in `kubernetes/tyk-control-plane/.env` file
- **GitOps Structure**: ArgoCD applications and values files already exist

## Required Changes

### 1. ✅ Customer Secrets (.env file) - COMPLETED
**File**: `kubernetes/tyk-control-plane/.env`

**Status**: ✅ COMPLETED - All required secrets now present:
```bash
# Copy this file and replace with your actual license keys
# Tyk License Keys - Replace with your actual licenses
DASHBOARD_LICENSE="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhbGxvd2VkX25vZGVzIjoiYjc1YTYwZWUtYWFkMi00MjBkLTZkMzItYWJjMTQyMDQ0ZDI3LGEzMDljN2E4LTVkODEtNGFiNi03MDkyLWY3YmM5NzUyMWQwOSxmMjE0ZWI5Ni1lZmQ1LTRhZDAtNWE5ZC0wMzZiM2Q4NGU1NjIsMmI4NGNkODAtNDUyMC00ODZjLTc5ZTEtYTQ5ZmJlOWY0YzUzLDMwNWNhN2RiLWZmODItNGEyOS02MGQ4LTY5NTJhZDU0NTZmNSx3MDUyM2VhNS0zYjFjLTRlZDktNTM1OC03ZDdlYzkwM2FkY2UsNzc2NTA0OGQtY2RmYy00ZmNlLTYzZDktNmE3ODg1NDdlOGVhLGM3ZDA2NGRjLWYyMmQtNDM4Mi01MzlmLWU3NjY5NmMzYzA0MCw2OGFmNWVkMi05MjA4LTQ0N2EtNjQ1Yi1jZGNhNzhiMjE5YzEsZjA5NmI1YjUtM2IwMS00MzAxLTZkMWUtZmYwMTk3N2NlM2ZjIiwiZXhwIjoxNzU0MDA2Mzk5LCJoaWQiOiJhaG1ldCIsImlhdCI6MTc1MTQwNDkzMiwibGljZW5zZV90eXBlIjoiaW50ZXJuYWwiLCJvd25lciI6IjY2YjYzYjQ2ZTNjNGQ1MDAwMTczOTRiMiIsInNjb3BlIjoibXVsdGlfdGVhbSxyYmFjLGdyYXBoLGZlZGVyYXRpb24sc3RyZWFtcyx0cmFjayIsInYiOiIyIn0.h_9fe0GJysApXVoDYQi4gGKE8VCf-AI7Nrg7LNwPjf_Eej_GFLDJFflvqMODmHTvieJj0C3BkY"
MDCB_LICENSE="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJTS1UiOiJUeWstTURDQi1FTlQiLCJleHAiOjE3NTQwMDYzOTksImhpZCI6ImFobWV0IiwibGljZW5zZV90eXBlIjoiaW50ZXJuYWwiLCJvd25lciI6IjY2YjYzYjQ2ZTNjNGQ1MDAwMTczOTRiMiJ9.vDyzb3fiUNuh2m6oxKoVerTm522LwQ2F5wvFjmPknMMqTaFfVVU84d4lMypIc2vrROS-CG0CHYfKNYMq6idEZzxgv3M66O42zJR8KZTicM5e-1Wx0nGdNpDPY-byKvlFqubjVxaIwOU3AQvCDTEncTkUBB3v-rHe4_T5pUaQGmc5CBiv4XtHrfeuUGan1aXOsPedGsfKmtkGixh4IUsEG

# Add these 2 missing secrets to your existing .env file:
API_SECRET="CHANGEME_GENERATE_RANDOM_STRING"
ADMIN_SECRET="CHANGEME_GENERATE_RANDOM_STRING"

# Note: You already have all other required secrets:
# ✅ DASHBOARD_LICENSE
# ✅ MDCB_LICENSE  
# ✅ PORTAL_LICENSE
# ✅ OPERATOR_LICENSE
# ✅ ADMIN_FIRST_NAME, ADMIN_LAST_NAME, ADMIN_EMAIL, ADMIN_PASSWORD
```

### 2. Update ArgoCD Application Configuration
**File**: `gitops/applications/tyk-control-plane.yaml`

**Key Changes Required**:
- Update component versions to 5.8.1 (keeping current versions)
- Switch from inline values to values file reference
- Enable MDCB component (currently disabled)
- Configure proper secret references

**Updated ArgoCD Application**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tyk-control-plane
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    chart: tyk-control-plane
    repoURL: https://helm.tyk.io/public/helm/charts/
    targetRevision: 3.0.0
    helm:
      releaseName: tyk-cp
      valueFiles:
        - ../tyk-control-plane/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: tyk
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 1m
```

### 3. Update Values File for Version 2.8.1
**File**: `gitops/tyk-control-plane/values.yaml`

**Key Changes Required**:
- Update all image tags to v5.8.1
- Configure proper secret references using `useSecretName`
- Enable MDCB component
- Set storageType to postgres
- Configure proper database and Redis connection strings

**Updated Values Configuration**:
```yaml
global:
  # Storage configuration
  storageType: postgres
  
  # Use existing secrets instead of inline values
  secrets:
    useSecretName: "tyk-control-plane-secret"
  
  # Admin user configuration
  adminUser:
    useSecretName: "tyk-control-plane-secret"
  
  # Component enablement
  components:
    bootstrap: true
    dashboard: true
    gateway: true
    pump: true
    mdcb: true
    devPortal: true
    operator: true

# Version 2.8.1 configuration
tyk-gateway:
  gateway:
    image:
      tag: v5.8.1
    service:
      type: ClusterIP
      port: 8080

tyk-dashboard:
  dashboard:
    image:
      tag: v5.8.1
    service:
      type: ClusterIP
      port: 3000

tyk-mdcb:
  mdcb:
    image:
      tag: v5.8.1
    service:
      type: ClusterIP
      port: 9091
    useSecretName: "tyk-control-plane-secret"

tyk-pump:
  pump:
    image:
      tag: v1.8.1
    backend:
      - "postgres"

tyk-dev-portal:
  enabled: true
  image:
    tag: v1.8.1
  useSecretName: "tyk-control-plane-secret"

tyk-operator:
  image:
    tag: v0.15.1
```

### 4. Create Secret Generation Script
**File**: `scripts/generate-argocd-secrets.sh`

**Purpose**: Generate Kubernetes secrets from both `.env` and `infrastructure.env` files

**Script Content**:
```bash
#!/bin/bash
set -e

echo "=== Generating Kubernetes Secrets for ArgoCD Deployment ==="

# Source environment files
source kubernetes/tyk-control-plane/.env
source kubernetes/tyk-control-plane/infrastructure.env

# Create namespace if it doesn't exist
kubectl create namespace tyk --dry-run=client -o yaml | kubectl apply -f -

# Generate API and Admin secrets if not provided
if [ "$API_SECRET" == "CHANGEME_GENERATE_RANDOM_STRING" ]; then
    API_SECRET=$(openssl rand -hex 32)
    echo "Generated API_SECRET: $API_SECRET"
fi

if [ "$ADMIN_SECRET" == "CHANGEME_GENERATE_RANDOM_STRING" ]; then
    ADMIN_SECRET=$(openssl rand -hex 32)
    echo "Generated ADMIN_SECRET: $ADMIN_SECRET"
fi

# Create comprehensive secret for all Tyk components
kubectl create secret generic tyk-control-plane-secret \
    --namespace=tyk \
    --from-literal=APISecret="$API_SECRET" \
    --from-literal=AdminSecret="$ADMIN_SECRET" \
    --from-literal=DashLicense="$DASHBOARD_LICENSE" \
    --from-literal=MDCBLicense="$MDCB_LICENSE" \
    --from-literal=DevPortalLicense="$PORTAL_LICENSE" \
    --from-literal=OperatorLicense="$OPERATOR_LICENSE" \
    --from-literal=adminUserFirstName="$ADMIN_FIRST_NAME" \
    --from-literal=adminUserLastName="$ADMIN_LAST_NAME" \
    --from-literal=adminUserEmail="$ADMIN_EMAIL" \
    --from-literal=adminUserPassword="$ADMIN_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create infrastructure secrets
kubectl create secret generic tyk-infrastructure-secret \
    --namespace=tyk \
    --from-literal=postgresHost="$POSTGRES_HOST" \
    --from-literal=postgresUser="$POSTGRES_USER" \
    --from-literal=postgresPassword="$POSTGRES_PASSWORD" \
    --from-literal
    --from-literal=postgresDatabase="$POSTGRES_DB" \
    --from-literal=redisHost="$REDIS_HOST" \
    --from-literal=redisPort="$REDIS_PORT" \
    --from-literal=redisPassword="$REDIS_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Kubernetes secrets created successfully!"
echo "Secrets created:"
echo "- tyk-control-plane-secret (licenses, admin user, API/Admin secrets)"
echo "- tyk-infrastructure-secret (database and Redis connections)"
```

### 5. Updated Values File Configuration
**File**: `gitops/tyk-control-plane/values.yaml`

**Complete Updated Configuration**:
```yaml
global:
  # Storage configuration
  storageType: postgres
  
  # PostgreSQL Configuration (references infrastructure secrets)
  postgres:
    host: 
      valueFrom:
        secretKeyRef:
          name: tyk-infrastructure-secret
          key: postgresHost
    port: 5432
    user: 
      valueFrom:
        secretKeyRef:
          name: tyk-infrastructure-secret
          key: postgresUser
    password: 
      valueFrom:
        secretKeyRef:
          name: tyk-infrastructure-secret
          key: postgresPassword
    database: 
      valueFrom:
        secretKeyRef:
          name: tyk-infrastructure-secret
          key: postgresDatabase
    sslmode: require

  # Redis Configuration (references infrastructure secrets)
  redis:
    addrs:
      - valueFrom:
          secretKeyRef:
            name: tyk-infrastructure-secret
            key: redisHost
    port:
      valueFrom:
        secretKeyRef:
          name: tyk-infrastructure-secret
          key: redisPort
    passSecret:
      name: tyk-infrastructure-secret
      keyName: redisPassword
    enableCluster: false
    useSSL: true

  # Use existing secrets for all configurations
  secrets:
    useSecretName: "tyk-control-plane-secret"
  
  # Admin user configuration
  adminUser:
    useSecretName: "tyk-control-plane-secret"
  
  # Component enablement
  components:
    bootstrap: true
    dashboard: true
    gateway: true
    pump: true
    mdcb: true
    devPortal: true
    operator: true

# Tyk Gateway Configuration - Version 2.8.1
tyk-gateway:
  gateway:
    image:
      tag: v5.8.1
    service:
      type: ClusterIP
      port: 8080
    ingress:
      enabled: false
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"

# Tyk Dashboard Configuration - Version 2.8.1
tyk-dashboard:
  dashboard:
    image:
      tag: v5.8.1
    service:
      type: ClusterIP
      port: 3000
    ingress:
      enabled: false
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

# Tyk MDCB Configuration - Version 2.8.1
tyk-mdcb:
  mdcb:
    image:
      tag: v5.8.1
    service:
      type: ClusterIP
      port: 9091
    ingress:
      enabled: false
    useSecretName: "tyk-control-plane-secret"
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"

# Tyk Pump Configuration
tyk-pump:
  pump:
    image:
      tag: v1.8.1
    backend:
      - "postgres"
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"

# Enterprise Developer Portal Configuration
tyk-dev-portal:
  enabled: true
  image:
    tag: v1.8.1
  service:
    type: ClusterIP
    port: 3001
  ingress:
    enabled: false
  useSecretName: "tyk-control-plane-secret"
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"

# Tyk Operator Configuration
tyk-operator:
  image:
    tag: v0.15.1
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

# External services (disabled - using infrastructure)
redis:
  enabled: false

postgresql:
  enabled: false
```

## Deployment Sequence

### Phase 1: Prerequisites
1. **Infrastructure Setup**:
   ```bash
   # Run Terraform to create infrastructure
   cd terraform/deployments/control-plane/azure
   terraform plan
   terraform apply
   
   # Extract infrastructure secrets
   ../../scripts/extract-infrastructure-secrets.sh
   ```

2. **Update Customer Secrets**:
   - Update `kubernetes/tyk-control-plane/.env` with the required secrets
   - Ad
d API_SECRET and ADMIN_SECRET if not already present

3. **Generate Kubernetes Secrets**:
   ```bash
   # Run the secret generation script
   ./scripts/generate-argocd-secrets.sh
   ```

### Phase 2: ArgoCD Application Updates
1. **Update ArgoCD Application**:
   - Modify `gitops/applications/tyk-control-plane.yaml` to use values file
   - Update component versions to 2.8.1
   - Enable MDCB component

2. **Update Values File**:
   - Update `gitops/tyk-control-plane/values.yaml` with correct versions
   - Configure proper secret references
   - Set storageType to postgres

### Phase 3: Deployment
1. **Deploy Prerequisites**:
   ```bash
   kubectl apply -f gitops/prerequisites/
   ```

2. **Deploy ArgoCD Application**:
   ```bash
   kubectl apply -f gitops/applications/tyk-control-plane.yaml
   ```

3. **Verify Deployment**:
   ```bash
   # Check ArgoCD application status
   kubectl get applications -n argocd
   
   # Check Tyk components
   kubectl get pods -n tyk
   kubectl get services -n tyk
   ```

## Verification Steps

### 1. Component Status Check
```bash
# Check all Tyk components are running
kubectl get pods -n tyk -l app.kubernetes.io/name=tyk-gateway
kubectl get pods -n tyk -l app.kubernetes.io/name=tyk-dashboard
kubectl get pods -n tyk -l app.kubernetes.io/name=tyk-mdcb
kubectl get pods -n tyk -l app.kubernetes.io/name=tyk-pump
kubectl get pods -n tyk -l app.kubernetes.io/name=tyk-dev-portal
kubectl get pods -n tyk -l app.kubernetes.io/name=tyk-operator
```

### 2. Version Verification
```bash
# Check image versions are correct (5.8.1)
kubectl describe pod -n tyk -l app.kubernetes.io/name=tyk-gateway | grep Image:
kubectl describe pod -n tyk -l app.kubernetes.io/name=tyk-dashboard | grep Image:
kubectl describe pod -n tyk -l app.kubernetes.io/name=tyk-mdcb | grep Image:
```

### 3. Secret Verification
```bash
# Verify secrets are created and referenced correctly
kubectl get secrets -n tyk
kubectl describe secret tyk-control-plane-secret -n tyk
kubectl describe secret tyk-infrastructure-secret -n tyk
```

### 4. ArgoCD Application Health
```bash
# Check ArgoCD application is healthy and synced
kubectl get application tyk-control-plane -n argocd
kubectl describe application tyk-control-plane -n argocd
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Secret Reference Issues
**Problem**: Pods failing to start due to missing secrets
**Solution**: 
- Verify secret names match exactly in values file
- Check secret keys are correct
- Ensure secrets exist in the correct namespace

#### 2. Version Compatibility Issues
**Problem**: Components failing to start with version 2.8.1
**Solution**:
- Verify all component versions are compatible
- Check if any configuration changes are needed for older versions
- Review Tyk documentation for version 2.8.1 requirements

#### 3. Database Connection Issues
**Problem**: Components cannot connect to PostgreSQL or Redis
**Solution**:
- Verify infrastructure.env file contains correct connection details
- Check network connectivity to database services
- Validate SSL/TLS configuration

#### 4. License Issues
**Problem**: Components failing due to invalid licenses
**Solution**:
- Verify license keys are valid and not expired
- Check license keys are properly formatted (no extra spaces/characters)
- Ensure license keys support the required features

## Summary

This deployment plan provides a comprehensive approach to deploying Tyk Control Plane using ArgoCD with the following key features:

- **Helm Chart Version**: 3.0.0
- **Tyk Component Versions**: 5.8.1 (Dashboard and Gateway)
- **Infrastructure**: Terraform-managed PostgreSQL and Redis
- **Secrets Management**: Kubernetes secrets with proper references
- **GitOps**: ArgoCD-managed deployment with values file
- **Components**: All Tyk components enabled (Gateway, Dashboard, MDCB, Pump, Developer Portal, Operator)

The plan ensures security by using Kubernetes secrets for all sensitive data and follows GitOps best practices for deployment management.

## Next Steps

1. **Review and approve this plan**
2. **Switch to Code mode to implement the changes**
3. **Test the deployment in a non-production environment**
4. **Deploy to production following the defined sequence**

## Files Modified/Created

1. **New**: `docs/argocd-deployment-plan.md` - This comprehensive deployment plan
2. **Update**: `kubernetes/tyk-control-plane/.env` - Add API_SECRET and ADMIN_SECRET
3
. **Update**: `gitops/applications/tyk-control-plane.yaml` - Switch to values file and update versions
4. **Update**: `gitops/tyk-control-plane/values.yaml` - Configure for version 2.8.1 and proper secrets
5. **New**: `scripts/generate-argocd-secrets.sh` - Script to generate all required secrets
6. **Update**: `gitops/prerequisites/tyk-chart-secret.yaml` - May need updates based on new secret structure

---

*This deployment plan was created to enable ArgoCD-based deployment of Tyk Control Plane version 5.8.1 with proper secret management and GitOps practices.*

## Phase 4: Post-Deployment Cleanup (After Verification)

### 1. Verify Deployment Success
Before any cleanup, ensure the new ArgoCD deployment is working correctly:
```bash
# Verify all components are running
kubectl get pods -n tyk
kubectl get services -n tyk
kubectl get applications -n argocd

# Test API connectivity
kubectl port-forward -n tyk svc/tyk-dashboard 3000:3000
# Access dashboard at http://localhost:3000

# Test gateway functionality
kubectl port-forward -n tyk svc/tyk-gateway 8080:8080
# Test API calls to gateway
```

### 2. Repository Cleanup (Only After Successful Verification)

#### Remove Old Deployment Files
```bash
# Remove old direct Helm deployment files
rm -rf kubernetes/tyk-control-plane/values.yaml
rm -rf kubernetes/tyk-control-plane/values-azure.yaml
rm -rf kubernetes/tyk-control-plane/base-values.yaml
rm -rf kubernetes/tyk-control-plane/deploy.sh
rm -rf kubernetes/tyk-control-plane/setup.sh
rm -rf kubernetes/tyk-control-plane/secret-provider-class.yaml
rm -rf kubernetes/tyk-control-plane/00-namespace.yaml

# Remove old deployment scripts
rm -rf scripts/deploy-tyk-control-plane.sh

# Remove old secret file (replaced by proper secret management)
rm -rf gitops/prerequisites/tyk-chart-secret.yaml
```

#### Update README.md
Replace the old deployment approach with the new GitOps approach:

```markdown
# Tyk Control Plane Deployment

## Overview
This repository provides a GitOps-based deployment approach for Tyk Control Plane using ArgoCD and Helm chart version 3.x.

## Prerequisites
- Terraform (for infrastructure)
- kubectl (configured for your cluster)
- ArgoCD installed in your cluster

## Deployment Steps

### 1. Infrastructure Setup
```bash
# Deploy infrastructure using Terraform
cd terraform/deployments/control-plane/azure
terraform init
terraform plan
terraform apply

# Extract infrastructure secrets
./scripts/extract-infrastructure-secrets.sh
```

### 2. Configure Customer Secrets
Update `kubernetes/tyk-control-plane/.env` with your license keys and admin details.

### 3. Generate Kubernetes Secrets
```bash
# Generate all required secrets
./scripts/generate-argocd-secrets.sh
```

### 4. Deploy via GitOps
```bash
# Deploy prerequisites
kubectl apply -f gitops/prerequisites/

# Deploy Tyk Control Plane
kubectl apply -f gitops/applications/tyk-control-plane.yaml
```

### 5. Verify Deployment
```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# Check Tyk components
kubectl get pods -n tyk
```

## Architecture
- **GitOps**: ArgoCD-managed deployment
- **Secrets**: Kubernetes secrets with proper separation
- **Components**: All Tyk components (Gateway, Dashboard, MDCB, Pump, Developer Portal, Operator)
- **Versions**: Tyk 5.8.1 with Helm chart 3.x
```

#### Clean Up Documentation
```bash
# Remove old documentation that's no longer relevant
rm -rf docs/tyk-control-plane-deployment.md  # If it exists and is outdated
rm -rf docs/deployment-playbook.md  # If it conflicts with new approach

# Keep relevant documentation
# - docs/argocd-deployment-plan.md (our new plan)
# - docs/gitops-deployment-guide.md (if it exists and is relevant)
# - docs/complete-walkthrough.md (if it's updated for new approach)
```

### 3. Repository Structure After Cleanup
```
├── README.md                           # Updated with GitOps approach
├── Makefile                           # Updated for new workflow
├── docs/
│   ├── argocd-deployment-plan.md      # This deployment plan
│   ├── gitops-deployment-guide.md     