# Tyk Control Plane Deployment Guide

## Overview

This document describes the complete deployment of Tyk Control Plane on Azure Kubernetes Service (AKS) with Azure Key Vault integration for secure secret management.

## Deployment Summary

### Infrastructure Components
- **Azure Kubernetes Service (AKS)**: `tyk-control-plane-dev-aks`
- **Azure PostgreSQL**: `tyk-control-plane-dev-postgres.postgres.database.azure.com`
- **Azure Redis Cache**: `tyk-control-plane-dev-redis.redis.cache.windows.net`
- **Azure Key Vault**: `tyk-control-plane-dev-kv`

### Deployed Tyk Components
- **Tyk Dashboard**: API management interface (2 replicas)
- **Tyk Gateway**: API Gateway for control plane (2 replicas)
- **Tyk MDCB**: Multi-Data Center Bridge for managing data planes (2 replicas)
- **Tyk Pump**: Analytics data processor (1 replica)
- **Tyk Developer Portal**: API developer portal (1 replica)

## Access Information

### Tyk Dashboard
- **URL**: http://4.226.39.207:3000
- **Admin Email**: admin@company.com
- **Admin Password**: test3123

### Tyk Gateway
- **URL**: http://20.250.199.37:8080
- **Health Check**: http://20.250.199.37:8080/hello

### Tyk MDCB
- **RPC Port**: 20.250.198.122:9091 (for data plane connections)
- **HTTP Port**: 20.250.198.122:8181 (for management/monitoring)

## Azure Key Vault Integration

### Secrets Store CSI Driver
The deployment uses Azure Key Vault Provider for Secrets Store CSI Driver to securely manage credentials:

- **Driver**: `secrets-store-csi-driver`
- **Provider**: `csi-secrets-store-provider-azure`
- **SecretProviderClass**: `tyk-azure-keyvault`

### Stored Secrets
All sensitive data is stored in Azure Key Vault and automatically synchronized to Kubernetes secrets:

#### Database Configuration
- `postgres-host`: PostgreSQL server hostname
- `postgres-user`: Database username
- `postgres-password`: Database password
- `postgres-database`: Database name
- `postgres-connection-string`: Full connection string

#### Redis Configuration
- `redis-host`: Redis cache hostname
- `redis-port`: Redis port (6380 for SSL)
- `redis-password`: Redis access key
- `redis-addrs`: Redis connection address

#### Tyk Licenses
- `dashboard-license`: Tyk Dashboard license key
- `mdcb-license`: Tyk MDCB license key
- `portal-license`: Tyk Developer Portal license key
- `operator-license`: Tyk Operator license key

#### Admin Configuration
- `admin-user-first-name`: Admin user first name
- `admin-user-last-name`: Admin user last name
- `admin-user-email`: Admin user email
- `admin-user-password`: Admin user password

#### Security Configuration
- `mdcb-security-secret`: MDCB HTTP endpoints authentication key

## Kubernetes Resources

### Namespaces
- `tyk`: Main namespace for all Tyk components

### Services
```
NAME                                   TYPE           EXTERNAL-IP      PORT
dashboard-svc-tyk-cp-tyk-dashboard     LoadBalancer   4.226.39.207     3000
gateway-svc-tyk-cp-tyk-gateway         LoadBalancer   20.250.199.37    8080
mdcb-svc-tyk-cp-tyk-mdcb               LoadBalancer   20.250.198.122   9091
dev-portal-svc-tyk-cp-tyk-dev-portal   ClusterIP      <none>           3001
pump-svc-health-tyk-cp-tyk-pump        ClusterIP      <none>           8083
```

### Secrets
- `tyk-postgres-secret`: Database connection details
- `tyk-redis-secret`: Redis connection details
- `tyk-secrets`: Main Tyk configuration secrets
- `tyk-mdcb-secret`: MDCB specific secrets
- `tyk-admin-user-secret`: Admin user credentials
- `tyk-dev-portal-secret`: Developer portal configuration

## Deployment Files

### Core Files
- [`setup-env.sh`](../kubernetes/tyk-control-plane/setup-env.sh): Environment configuration
- [`values-azure.yaml`](../kubernetes/tyk-control-plane/values-azure.yaml): Helm values for Azure deployment
- [`secret-provider-class.yaml`](../kubernetes/tyk-control-plane/secret-provider-class.yaml): Azure Key Vault integration
- [`deploy-tyk-control-plane.sh`](../kubernetes/tyk-control-plane/deploy-tyk-control-plane.sh): Main deployment script

### Configuration Files
- [`.env`](../kubernetes/tyk-control-plane/.env): License keys and admin user details
- [`update-licenses.sh`](../kubernetes/tyk-control-plane/update-licenses.sh): Update Key Vault with new licenses

## How to Update Licenses

1. Edit the `.env` file with your new license keys
2. Run the update script:
   ```bash
   cd kubernetes/tyk-control-plane
   ./update-licenses.sh
   ```
3. Restart the secret sync to pull new secrets:
   ```bash
   kubectl rollout restart deployment tyk-secret-sync -n tyk
   ```

## Data Plane Connection

To connect Tyk Data Planes to this Control Plane:

### 1. Get Connection Details
```bash
# Get organization ID and API key
export USER_API_KEY=$(kubectl get secret --namespace tyk tyk-operator-conf -o jsonpath="{.data.TYK_AUTH}" | base64 --decode)
export ORG_ID=$(kubectl get secret --namespace tyk tyk-operator-conf -o jsonpath="{.data.TYK_ORG}" | base64 --decode)

# MDCB connection string
export MDCB_CONNECTIONSTRING="20.250.198.122:9091"
```

### 2. Deploy Data Plane
Use the `tyk-data-plane`