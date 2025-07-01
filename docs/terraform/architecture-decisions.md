# Architecture Notes

This document explains the current design decisions for the Tyk infrastructure deployment.

## Current Implementation

The project currently provides infrastructure deployment for Azure only. The design aims to be vendor-agnostic to support future cloud providers.

## Cloud Service Categories

### Managed Kubernetes Service
We use managed Kubernetes services rather than self-managed clusters to reduce operational overhead.

**Current Implementation:**
- **Azure**: Azure Kubernetes Service (AKS)

**Future Planned:**
- **AWS**: Elastic Kubernetes Service (EKS)
- **GCP**: Google Kubernetes Engine (GKE)

### Managed Database Service
We use managed PostgreSQL services for the control plane database.

**Current Implementation:**
- **Azure**: PostgreSQL Flexible Server

**Future Planned:**
- **AWS**: RDS for PostgreSQL
- **GCP**: Cloud SQL for PostgreSQL

### Managed Cache Service
We use managed Redis services for the control plane cache and session storage.

**Current Implementation:**
- **Azure**: Azure Cache for Redis

**Future Planned:**
- **AWS**: ElastiCache for Redis
- **GCP**: Memorystore for Redis

### Secrets Management
We provide optional integration with cloud-native secret management services.

**Current Implementation:**
- **Azure**: Azure Key Vault (optional)

**Future Planned:**
- **AWS**: AWS Secrets Manager (optional)
- **GCP**: Google Secret Manager (optional)

## Design Principles

### Managed vs Self-Managed
We default to managed services to reduce operational complexity, though this increases cost. You can replace these with your own self-managed alternatives if preferred.

### Vendor-Agnostic Structure
The Terraform structure is organized to support multiple cloud providers:
```
terraform/
├── deployments/
│   └── control-plane/
│       ├── azure/     # Current implementation
│       ├── aws/       # Future
│       └── gcp/       # Future
```

### Environment Isolation
Each environment (dev/staging/prod) gets separate infrastructure stacks for complete isolation.

### Security Defaults
We configure secure defaults like private database access, though customers can modify these based on their requirements.

