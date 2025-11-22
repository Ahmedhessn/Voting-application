# Voting Application - Complete Deployment Overview

This document provides an overview of all deployment options and guides for the Voting Application.

## 🎯 Deployment Requirements Met

✅ **Infrastructure as Code (Terraform)**
- Multi-environment support (dev, staging, prod)
- Azure AKS cluster provisioning
- Local cluster support (minikube/k3s/microk8s)
- Networking (VNet, Subnet, NSG)
- Security groups and firewall rules
- Ingress controller deployment

✅ **Kubernetes Deployment**
- Helm charts (production-grade)
- Kubernetes manifests (for reference)
- ConfigMaps and Secrets
- Resource limits and requests
- Health probes (liveness, readiness)
- Pod Security Admission (PSA) - Restricted mode
- NetworkPolicies for database isolation

✅ **PostgreSQL and Redis**
- Helm charts (Bitnami) for production deployment
- Kubernetes manifests provided for reference
- Persistence enabled
- Restricted access via NetworkPolicies
- Non-root security contexts

✅ **Production-Grade Practices**
- Secrets management (Azure Key Vault integration)
- Network isolation
- Resource limits
- Health checks with proper timeouts
- Non-root containers
- Pod Security Standards

✅ **Documentation**
- Local cluster setup guides
- Trade-offs documentation
- Production deployment guide
- Multi-environment guides

## 📁 Project Structure

```
Voting-application/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output values
│   ├── dev.tfvars            # Development environment
│   ├── prod.tfvars           # Production environment
│   ├── README.md             # Terraform guide
│   └── LOCAL_CLUSTER_TRADEOFFS.md  # Trade-offs documentation
│
├── helm/                     # Helm charts
│   └── voting-app/
│       ├── Chart.yaml        # Chart metadata
│       ├── values.yaml       # Default values
│       ├── values-aks.yaml   # AKS-specific values
│       ├── values-dev.yaml   # Development values
│       ├── values-prod.yaml  # Production values
│       └── templates/        # Kubernetes templates
│           ├── namespace.yaml
│           ├── configmap.yaml
│           ├── secret.yaml
│           ├── secret-external.yaml  # External secrets
│           ├── vote-deployment.yaml
│           ├── result-deployment.yaml
│           ├── worker-deployment.yaml
│           ├── network-policy.yaml
│           ├── network-policy-database.yaml  # Database isolation
│           └── ...
│
├── aks/                      # Kubernetes manifests (kubectl)
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── vote-deployment.yaml
│   ├── result-deployment.yaml
│   ├── worker-deployment.yaml
│   ├── postgres-deployment.yaml
│   ├── redis-deployment.yaml
│   ├── network-policy.yaml
│   ├── DEPLOYMENT_GUIDE.md
│   ├── HELM_DEPLOYMENT_GUIDE.md
│   └── ...
│
├── k8s/                      # Kustomize manifests
│   ├── base/                 # Base manifests
│   └── overlays/             # Environment overlays
│       ├── dev/
│       └── prod/
│
├── LOCAL_CLUSTER_SETUP.md    # Local cluster setup guide
├── PRODUCTION_DEPLOYMENT_GUIDE.md  # Production guide
└── DEPLOYMENT_OVERVIEW.md    # This file
```

## 🚀 Quick Start

### Option 1: Azure AKS (Production)

```bash
# 1. Provision infrastructure
cd terraform
terraform init
terraform workspace new prod
terraform apply -var-file=prod.tfvars

# 2. Build and push images
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
az acr login --name $(terraform output -raw acr_name)
docker build -t $ACR_LOGIN_SERVER/vote:v2 ../vote
docker push $ACR_LOGIN_SERVER/vote:v2
# ... (repeat for result and worker)

# 3. Deploy application
cd ../helm/voting-app
helm install voting-app . \
  --namespace voting-app \
  --create-namespace \
  --values values-aks.yaml \
  --values values-prod.yaml
```

### Option 2: Local Cluster (Development)

```bash
# 1. Start local cluster (minikube/k3s/microk8s)
minikube start
# or
# k3s is already running
# or
microk8s status --wait-ready

# 2. Provision infrastructure
cd terraform
terraform apply -var-file=dev.tfvars \
  -var="deploy_to_azure=false"

# 3. Deploy application
cd ../helm/voting-app
helm install voting-app . \
  --namespace voting-app \
  --create-namespace \
  --values values-dev.yaml
```

## 📚 Documentation Guide

### For Infrastructure

1. **Terraform Setup**
   - Read: `terraform/README.md`
   - Covers: Multi-environment, networking, security groups

2. **Local Cluster Setup**
   - Read: `LOCAL_CLUSTER_SETUP.md`
   - Covers: minikube, k3s, microk8s setup

3. **Trade-offs**
   - Read: `terraform/LOCAL_CLUSTER_TRADEOFFS.md`
   - Covers: Azure vs local cluster comparison

### For Application Deployment

1. **Helm Deployment (Recommended)**
   - Read: `aks/HELM_DEPLOYMENT_GUIDE.md`
   - Quick Start: `aks/HELM_QUICK_START.md`
   - Covers: Helm charts, values, upgrades

2. **kubectl Deployment**
   - Read: `aks/DEPLOYMENT_GUIDE.md`
   - Quick Start: `aks/QUICK_START.md`
   - Covers: Direct manifest deployment

3. **Production Deployment**
   - Read: `PRODUCTION_DEPLOYMENT_GUIDE.md`
   - Covers: Production best practices, security, monitoring

## 🔐 Security Features

### Implemented

✅ **Pod Security Admission (PSA)**
- Namespace-level: `restricted` mode
- Enforces non-root, read-only root filesystem, etc.

✅ **Network Policies**
- Database isolation (PostgreSQL only from worker/result)
- Redis isolation (only from vote/worker)
- Frontend ingress rules

✅ **Non-Root Containers**
- All containers run as non-root users
- Proper UIDs configured (1000 for apps, 999 for DBs)

✅ **Resource Limits**
- CPU and memory limits on all pods
- Prevents resource exhaustion

✅ **Secrets Management**
- Support for Azure Key Vault
- External Secrets Operator integration
- Never store secrets in code

✅ **Health Probes**
- Liveness probes with proper timeouts
- Readiness probes with failure thresholds
- Prevents serving traffic to unhealthy pods

## 🗄️ Database Deployment

### Production (Recommended)

**PostgreSQL and Redis via Helm (Bitnami)**
- Configured in Terraform
- Persistence enabled
- Resource limits
- Security contexts
- Network policies

### Development/Reference

**Kubernetes Manifests**
- Provided in `aks/` and `k8s/base/`
- Use for learning or custom deployments
- Not recommended for production

## 🌍 Multi-Environment Support

### Environments

1. **Development** (`dev`)
   - Local cluster or small AKS
   - Minimal resources
   - Development values

2. **Staging** (`staging`)
   - AKS cluster
   - Production-like configuration
   - Testing environment

3. **Production** (`prod`)
   - Full AKS cluster
   - High availability
   - Production values

### Configuration

**Terraform Workspaces:**
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

**Helm Values:**
- `values-dev.yaml` - Development
- `values-prod.yaml` - Production
- `values-aks.yaml` - AKS-specific

## 📊 Monitoring and Observability

### Azure Monitor (AKS)

- Enabled via Terraform
- Log Analytics integration
- Metrics and alerts

### Application Insights

- Optional integration
- APM capabilities
- Performance monitoring

## 🔄 CI/CD Integration

### Recommended Pipeline

1. **Build** - Docker images
2. **Push** - To Azure Container Registry
3. **Deploy** - Using Helm
4. **Test** - Smoke tests
5. **Monitor** - Health checks

### Example GitHub Actions

```yaml
- name: Deploy to AKS
  run: |
    helm upgrade --install voting-app ./helm/voting-app \
      --namespace voting-app \
      --values values-aks.yaml \
      --values values-prod.yaml
```

## 🆘 Troubleshooting

### Common Issues

1. **Pods not starting**
   - Check: `kubectl describe pod <pod-name>`
   - Check: `kubectl logs <pod-name>`

2. **Database connection issues**
   - Check: Network policies
   - Check: Service endpoints
   - Check: Secrets

3. **Image pull errors**
   - Check: ACR credentials
   - Check: Image names
   - Check: Pull secrets

4. **Network policy blocking traffic**
   - Check: Network policy rules
   - Temporarily disable for debugging

## 📖 Next Steps

1. ✅ **Review** all documentation
2. ✅ **Choose** deployment method (Helm recommended)
3. ✅ **Set up** infrastructure (Terraform)
4. ✅ **Deploy** application
5. ✅ **Configure** monitoring
6. ✅ **Set up** CI/CD pipeline

## 🔗 Quick Links

- [Terraform Guide](./terraform/README.md)
- [Helm Deployment](./aks/HELM_DEPLOYMENT_GUIDE.md)
- [Production Guide](./PRODUCTION_DEPLOYMENT_GUIDE.md)
- [Local Cluster Setup](./LOCAL_CLUSTER_SETUP.md)
- [Trade-offs](./terraform/LOCAL_CLUSTER_TRADEOFFS.md)

## ✅ Checklist

Before deploying to production:

- [ ] Infrastructure provisioned via Terraform
- [ ] Secrets stored in Azure Key Vault
- [ ] Images built and pushed to ACR
- [ ] Helm values configured
- [ ] Network policies enabled
- [ ] Resource limits set
- [ ] Monitoring configured
- [ ] Backup strategy in place
- [ ] Disaster recovery plan
- [ ] Documentation reviewed

## 🎓 Learning Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure AKS Documentation](https://learn.microsoft.com/azure/aks/)

---

**Ready to deploy?** Start with [PRODUCTION_DEPLOYMENT_GUIDE.md](./PRODUCTION_DEPLOYMENT_GUIDE.md) for step-by-step instructions!

