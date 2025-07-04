# Tyk Control Plane Operations Repository

This repository provides comprehensive deployment solutions for Tyk Control Plane, supporting both traditional script-based deployment and modern GitOps workflows.

## 🚀 Quick Start

### Traditional Helm Deployment
```bash
# One-command Helm-based deployment
make helm-deploy
```

### GitOps Deployment
```bash
# One-command GitOps deployment
make gitops-deploy
```

## 📁 Repository Structure

```
tyk-ops/
├── terraform/                     # Infrastructure as Code
│   └── deployments/control-plane/ # Terraform configurations
├── kubernetes/                    # Kubernetes manifests
│   └── tyk-control-plane/         # Helm values and configs
├── gitops/                        # GitOps manifests
│   ├── applications/              # ArgoCD applications
│   ├── prerequisites/             # Prerequisites (cert-manager, CRDs)
│   └── control-plane/             # Control plane manifests
├── scripts/                       # Deployment scripts
│   ├── install-argocd.sh         # ArgoCD installation
│   ├── setup-gitops.sh           # GitOps setup
│   └── [traditional scripts...]
└── docs/                          # Documentation
    ├── deployment-playbook.md     # Traditional deployment guide
    └── gitops-deployment-guide.md # GitOps deployment guide
```

## 🎯 Deployment Options

### 1. Traditional Helm-Based Deployment

Perfect for getting started quickly or when you need manual control:

```bash
# Deploy infrastructure
terraform apply -var-file="examples/dev.tfvars"

# Extract secrets
./scripts/extract-infrastructure-secrets.sh

# Setup prerequisites
./scripts/setup-cluster-prerequisites.sh

# Deploy Tyk Control Plane
./scripts/deploy-tyk-control-plane.sh
```

**Benefits:**
- Quick setup
- Manual control
- Easy troubleshooting
- Immediate feedback

### 2. GitOps with ArgoCD

Modern, production-ready approach for scalable deployments:

```bash
# 1. Provision infrastructure (AKS cluster + databases)
cd terraform/deployments/control-plane/azure
terraform apply -var-file="examples/dev.tfvars"

# 2. Extract secrets and configure kubectl
./scripts/extract-infrastructure-secrets.sh

# 3. Install ArgoCD on the provisioned cluster
make install-argocd

# 4. Setup Tyk applications in ArgoCD (auto-detects your Git repo)
make setup-gitops

# 5. Monitor ArgoCD deployment (Tyk deploys automatically)
make gitops-status
```

**🔄 How GitOps Works**: Step 4 creates ArgoCD applications that automatically deploy:
- **Prerequisites**: cert-manager, Tyk Operator CRDs, namespaces
- **Tyk Control Plane**: Dashboard, Gateway, MDCB, Pump, Developer Portal, Operator

**� Demo Repository**: Fork this repository and the setup script automatically detects your fork and configures ArgoCD to use it!

**Benefits:**
- Declarative configuration
- Automated synchronization
- Audit trail and rollback
- Multi-environment support

## 🏗️ Architecture

### Components Deployed
- **Tyk Dashboard**: API management interface
- **Tyk Gateway**: API gateway for control plane
- **Tyk MDCB**: Multi-Data Center Bridge
- **Tyk Pump**: Analytics processor
- **Tyk Developer Portal**: API portal
- **Tyk Operator**: Kubernetes-native API management

### Infrastructure Support
- **Azure AKS**: Current implementation
- **AWS EKS**: Planned support
- **GCP GKE**: Planned support
- **DigitalOcean DOKS**: Planned support

## 🔧 Configuration

### Environment Files
- `.env`: Tyk licenses and admin credentials
- `infrastructure.env`: Generated from Terraform outputs

### Terraform Variables
- `dev.tfvars`: Development environment
- `staging.tfvars`: Staging environment
- `prod.tfvars`: Production environment

## 📊 Monitoring

### Check Deployment Status
```bash
# Traditional deployment
make status

# GitOps deployment
make gitops-status
```

### Access Services
```bash
# Tyk Dashboard
kubectl port-forward -n tyk svc/tyk-cp-tyk-dashboard 3000:3000

# Developer Portal
kubectl port-forward -n tyk svc/tyk-cp-tyk-dev-portal 3001:3001

# Tyk Gateway
kubectl port-forward -n tyk svc/tyk-cp-tyk-gateway 8080:8080
```

### ArgoCD Dashboard (GitOps)
```bash
# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
```

## 🛠️ Available Commands

### Traditional Helm Deployment
```bash
make setup-prerequisites  # Install prerequisites
make deploy               # Deploy Tyk Control Plane
make helm-deploy          # Complete Helm-based deployment
make status              # Check deployment status
```

### GitOps Deployment
```bash
make install-argocd      # Install ArgoCD
make setup-gitops        # Setup GitOps applications
make gitops-deploy       # Complete GitOps deployment
make gitops-status       # Check GitOps status
```

### Monitoring Commands
```bash
make logs-dashboard      # Show Dashboard logs
make logs-mdcb          # Show MDCB logs
make logs-portal        # Show Portal logs
make logs-all           # Show all component logs
```

## 📚 Documentation

### Deployment Guides
- **[Traditional Deployment Playbook](docs/deployment-playbook.md)**: Complete guide for script-based deployment
- **[GitOps Deployment Guide](docs/gitops-deployment-guide.md)**: Comprehensive ArgoCD-based deployment
- **[Terraform Deployment Guide](docs/terraform/deployment-guide.md)**: Infrastructure provisioning details

### Architecture Documentation
- **[Architecture Decisions](docs/terraform/architecture-decisions.md)**: Infrastructure design decisions
- **[Tyk Control Plane Deployment](docs/tyk-control-plane-deployment.md)**: Component-specific deployment details

## 🔐 Security

### Secret Management
- Infrastructure secrets generated from Terraform outputs
- Kubernetes secrets created automatically
- No secrets committed to Git repository
- Support for external secret management (Vault, External Secrets Operator)

### Network Security
- All services deployed with ClusterIP (no internet exposure)
- SSL/TLS enabled for all communications
- Network policies can be applied for additional security

## 🌍 Multi-Environment Support

### Environment Configuration
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

## 🚨 Troubleshooting

### Common Issues
1. **Tyk Operator CrashLoopBackOff**: Check CRD installation
2. **MDCB Issues**: Verify license and security secrets
3. **Database Connection**: Check PostgreSQL connection strings
4. **ArgoCD Sync Issues**: Check application status and logs

### Get Help
```bash
# Check all pods
kubectl get pods -n tyk

# Check recent events
kubectl get events -n tyk --sort-by='.lastTimestamp'

# Check ArgoCD applications (GitOps)
kubectl get applications -n argocd
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the troubleshooting sections in the documentation
- Review the logs using the provided commands
- Open an issue in this repository
- Contact the Tyk team for enterprise support

---

**Get started with Tyk Control Plane today!** 🚀

Choose your deployment method:
- **Quick Start**: `make helm-deploy` (Traditional Helm)
- **Production Ready**: `make gitops-deploy` (GitOps)
