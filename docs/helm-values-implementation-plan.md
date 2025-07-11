# Tyk Control Plane GitOps Implementation Plan

## Current Issue
We've been trying to use ArgoCD inline values with custom secret injection, but this doesn't work properly with the Tyk Helm chart. The chart has built-in secret management that we should leverage.

## Solution: Use Helm Chart's Built-in Secret Management

### Step 1: Create Proper Helm Values File

Based on the `helm show values` output, the Tyk chart provides these secret reference patterns:

#### Global Secret References
```yaml
global:
  secrets:
    useSecretName: "tyk-control-plane-secret"  # Main secret for API/Admin secrets
  
  adminUser:
    useSecretName: "tyk-control-plane-secret"  # Admin user credentials
  
  license:
    dashboard: ""  # Will be referenced from secret
    operator: ""   # Will be referenced from secret
```

#### Database Secret References
```yaml
global:
  postgres:
    # Use individual secret references instead of inline values
    hostSecret:
      name: "tyk-infrastructure-secret"
      keyName: "postgresHost"
    userSecret:
      name: "tyk-infrastructure-secret" 
      keyName: "postgresUser"
    passwordSecret:
      name: "tyk-infrastructure-secret"
      keyName: "postgresPassword"
    databaseSecret:
      name: "tyk-infrastructure-secret"
      keyName: "postgresDatabase"
```

#### Redis Secret References
```yaml
global:
  redis:
    # Use secret reference for Redis address
    addrsSecret:
      name: "tyk-infrastructure-secret"
      keyName: "redisAddr"
    passSecret:
      name: "tyk-infrastructure-secret"
      keyName: "redisPassword"
```

### Step 2: Component Configuration

#### Enable Required Components
```yaml
global:
  components:
    bootstrap: true
    pump: false
    devPortal: false  # Start minimal, add later
    operator: false   # Start minimal, add later

tyk-dashboard:
  dashboard:
    # Use correct component versions
    image:
      tag: v5.8.1

tyk-gateway:
  gateway:
    image:
      tag: v5.8.1

tyk-mdcb:
  mdcb:
    # Enable MDCB for control plane
    image:
      tag: v2.8.1
    useSecretName: "tyk-control-plane-secret"
```

### Step 3: Secret Generation Strategy

#### Update Secret Generation Script
The `scripts/generate-argocd-secrets.sh` should create secrets with the exact field names expected by the Helm chart:

**tyk-control-plane-secret:**
- `APISecret` - from .env API_SECRET
- `AdminSecret` - from .env ADMIN_SECRET  
- `DashLicense` - from .env DASH_LICENSE
- `MDCBLicense` - from .env MDCB_LICENSE
- `OperatorLicense` - from .env OPERATOR_LICENSE
- `PortalLicense` - from .env PORTAL_LICENSE
- `adminUserFirstName` - from .env ADMIN_FIRST_NAME
- `adminUserLastName` - from .env ADMIN_LAST_NAME
- `adminUserEmail` - from .env ADMIN_EMAIL
- `adminUserPassword` - from .env ADMIN_PASSWORD

**tyk-infrastructure-secret:**
- `postgresHost` - from infrastructure.env
- `postgresUser` - from infrastructure.env
- `postgresPassword` - from infrastructure.env
- `postgresDatabase` - from infrastructure.env
- `redisAddr` - formatted as "host:port" from infrastructure.env
- `redisPassword` - from infrastructure.env

### Step 4: ArgoCD Application Update

Update `gitops/applications/tyk-control-plane.yaml` to:
1. Remove all inline helm values
2. Reference the values file in the Git repository
3. Ensure proper chart version and repository

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tyk-control-plane
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/TykTechnologies/tyk-ops.git
    targetRevision: HEAD
    path: gitops/tyk-control-plane
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: tyk
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### Step 5: Implementation Steps

1. **Create new values.yaml** - Replace existing with proper Helm chart format
2. **Update secret generation script** - Use correct field names
3. **Update ArgoCD application** - Remove