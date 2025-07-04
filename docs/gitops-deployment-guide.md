# GitOps Deployment Guide for Tyk Control Plane

This guide explains how to deploy Tyk Control Plane using GitOps with ArgoCD, providing automated, declarative, and version-controlled deployment management.

## Overview

The GitOps approach transforms your Tyk Control Plane deployment from manual script-based deployment to automated, Git-driven deployment using ArgoCD. This provides:

- **Declarative**: All configurations stored in Git
- **Automated**: ArgoCD handles deployment and synchronization
- **Auditable**: Complete deployment history and rollback capabilities
- **Consistent**: Same deployment process across all environments

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Infrastructure    │    │      ArgoCD         │    │   Tyk Control       │
│   (Terraform)       │───▶│   (GitOps Engine)   │───▶│   Plane Components  │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
          │                          │                          │
          ▼                          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│  Extract Secrets    │    │  App-of-Apps        │    │  • Dashboard        │
│  Create K8s Secrets │    │  • Prerequisites    │    │  • Gateway          │
│                     │    │  • Control Plane    │    │  • MDCB             │
└─────────────────────┘    └─────────────────────┘    │  • Pump             │
                                                      │  • Developer Portal │
                                                      │  • Operator         │
                                                      └─────────────────────┘
```

## GitOps Repository Structure

```
tyk-ops/
├── gitops/
│   ├── applications/                 # ArgoCD Applications
│   │   ├── root-app.yaml            # App-of-Apps root
│   │   ├── prerequisites-app.yaml   # Prerequisites application
│   │   └── control-plane-app.yaml   # Control plane application
│   ├── prerequisites/               # Prerequisites manifests
│   │   ├── namespaces.yaml         # Kubernetes namespaces
│   │   ├── cert-manager-app.yaml   # cert-manager Helm app
│   │   └── tyk-operator-crds.yaml  # Tyk Operator CRDs job
│   └── control-plane/              # Control plane manifests
│       ├── application.yaml        # Tyk Control Plane Helm app
│       └── values.yaml             # Helm values with secret refs
├── scripts/
│   ├── install-argocd.sh          # ArgoCD installation
│   ├── setup-gitops.sh            # GitOps setup
│   └── [existing scripts...]
└── [existing directories...]
```

## Prerequisites

### Required Tools
- **kubectl**: Kubernetes command-line tool
- **Terraform**: Infrastructure provisioning (existing)
- **ArgoCD CLI**: Optional, for advanced management

### Required Permissions
- Kubernetes cluster admin permissions
- Access to infrastructure secrets (Azure Key Vault, etc.)

## Step-by-Step GitOps Deployment

### Phase 1: Infrastructure Provisioning (Terraform)

```bash
# 1. Navigate to Terraform directory
cd terraform/deployments/control-plane/azure

# 2. Initialize Terraform
terraform init

# 3. Plan infrastructure deployment
terraform plan -var-file="examples/dev.tfvars"

# 4. Deploy infrastructure (including AKS cluster)
terraform apply -var-file="examples/dev.tfvars"

# 5. Extract infrastructure secrets and configure kubectl
./scripts/extract-infrastructure-secrets.sh
```

**What Terraform creates:**
- **AKS Cluster**: Kubernetes cluster with system-assigned identity
- **PostgreSQL Flexible Server**: Database for Tyk components
- **Redis Cache**: Caching layer for Tyk
- **Virtual Network**: Network infrastructure with subnets
- **Private DNS Zones**: For secure database connectivity
- **Resource Group**: Container for all resources

**What extract-infrastructure-secrets.sh does:**
- Extracts Terraform outputs (database URLs, passwords, etc.)
- Configures kubectl with AKS credentials
- Creates environment files for GitOps setup

### Phase 2: ArgoCD Installation

```bash
# 3. Install ArgoCD
./scripts/install-argocd.sh
```

**What this installs:**
- ArgoCD server, controller, and components
- Repository connection to tyk-ops
- Initial admin credentials

### Phase 3: GitOps Setup

```bash
# 4. Setup GitOps deployment
./scripts/setup-gitops.sh
```

**What this creates:**
- Kubernetes secrets from infrastructure data
- ArgoCD root application
- Automated deployment of all components

### Phase 4: Monitor and Verify

```bash
# 5. Monitor deployment
make gitops-status

# 6. Check ArgoCD applications
kubectl get applications -n argocd -w

# 7. Check Tyk pods
kubectl get pods -n tyk -w
```

**What this monitors:**
- ArgoCD application sync status
- Tyk component deployment progress
- Pod health and readiness

## One-Command GitOps Deployment

For complete automation, use the Makefile:

```bash
# Deploy everything using GitOps
make gitops-deploy
```

This single command:
1. Deploys infrastructure with Terraform
2. Extracts secrets automatically
3. Installs ArgoCD
4. Sets up GitOps applications
5. Monitors deployment progress

## ArgoCD Application Structure

### App-of-Apps Pattern

The deployment uses ArgoCD's App-of-Apps pattern:

```yaml
# Root Application (gitops/applications/root-app.yaml)
tyk-control-plane-apps
├── tyk-prerequisites     # Wave 0: Prerequisites
│   ├── namespaces       # Kubernetes namespaces
│   ├── cert-manager     # SSL certificate management
│   └── tyk-operator-crds # Tyk Operator CRDs
└── tyk-control-plane    # Wave 1: Control plane
    └── tyk-helm-chart   # Tyk components via Helm
```

### Sync Waves

Applications are deployed in waves to ensure proper dependencies:

- **Wave 0**: Prerequisites (namespaces, cert-manager, CRDs)
- **Wave 1**: Control plane (Tyk components)

## Secret Management

### Secret Creation Flow

```bash
# Infrastructure secrets (from Terraform)
terraform output → environment files → Kubernetes secrets

# GitOps references
Helm values → secret references → existing secrets
```

### Secret Types

1. **PostgreSQL Secret** (`tyk-postgres-secret`)
   - Database connection details
   - Connection strings with URL encoding

2. **Redis Secret** (`tyk-redis-secret`)
   - Redis connection details
   - Authentication credentials

3. **License Secret** (`tyk-license-secret`)
   - Tyk component licenses
   - Dashboard, MDCB, Portal, Operator

4. **Security Secret** (`tyk-security-secret`)
   - API and Admin secrets
   - MDCB security tokens

5. **Admin User Secret** (`tyk-admin-secret`)
   - Bootstrap admin user details
   - Dashboard and Portal access

## Accessing Services

### ArgoCD Dashboard

```bash
# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser
https://localhost:8080

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode
```

### Tyk Services

```bash
# Tyk Dashboard
kubectl port-forward -n tyk svc/tyk-cp-tyk-dashboard 3000:3000
# Access: http://localhost:3000

# Developer Portal
kubectl port-forward -n tyk svc/tyk-cp-tyk-dev-portal 3001:3001
# Access: http://localhost:3001

# Tyk Gateway
kubectl port-forward -n tyk svc/tyk-cp-tyk-gateway 8080:8080
# Access: http://localhost:8080
```

## Multi-Environment Support

### Environment-Specific Configurations

```bash
# Development
terraform apply -var-file="examples/dev.tfvars"

# Staging
terraform apply -var-file="examples/staging.tfvars"

# Production
terraform apply -var-file="examples/prod.tfvars"
```

### GitOps Branch Strategy

- **main**: Production deployments
- **staging**: Staging deployments
- **develop**: Development deployments

Each environment can track different branches:

```yaml
# ArgoCD Application
spec:
  source:
    targetRevision: main      # Production
    targetRevision: staging   # Staging
    targetRevision: develop   # Development
```

## Troubleshooting

### Common Issues

#### 1. ArgoCD Application Not Syncing

```bash
# Check application status
kubectl get applications -n argocd

# Check specific application
kubectl describe application tyk-prerequisites -n argocd

# Force sync
kubectl patch application tyk-prerequisites -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

#### 2. Tyk Operator CRDs Not Installing

```bash
# Check CRD installation job
kubectl get jobs -n tyk

# Check job logs
kubectl logs -n tyk job/install-tyk-operator-crds

# Manually verify CRDs
kubectl get crd | grep tyk
```

#### 3. Secret Reference Errors

```bash
# Check if secrets exist
kubectl get secrets -n tyk

# Verify secret contents
kubectl get secret tyk-postgres-secret -n tyk -o yaml

# Check Helm values
kubectl get configmap tyk-values-config -n tyk -o yaml
```

### Monitoring Commands

```bash
# ArgoCD applications
kubectl get applications -n argocd -w

# Tyk pods
kubectl get pods -n tyk -w

# Application events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Sync application manually
argocd app sync tyk-control-plane-apps
```

## Customization

### Adding New Components

1. Create new ArgoCD application in `gitops/applications/`
2. Add component manifests in appropriate subdirectory
3. Update root application to include new component
4. Commit changes to Git

### Environment-Specific Values

```yaml
# gitops/control-plane/values-dev.yaml
# gitops/control-plane/values-staging.yaml
# gitops/control-plane/values-prod.yaml
```

### Custom Domains

```yaml
# Add to ArgoCD application
spec:
  source:
    helm:
      values: |
        tyk-gateway:
          gateway:
            ingress:
              enabled: true
              hosts:
                - gateway.example.com
```

## Security Considerations

### Secret Management Best Practices

1. **Never commit secrets to Git**
2. **Use external secret management** (Vault, External Secrets Operator)
3. **Rotate secrets regularly**
4. **Use least privilege access