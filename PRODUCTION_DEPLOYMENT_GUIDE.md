# Production Deployment Guide - Voting Application

This comprehensive guide covers deploying the Voting Application to production using Terraform, Helm, and Kubernetes best practices.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Provisioning](#infrastructure-provisioning)
4. [Secrets Management](#secrets-management)
5. [Application Deployment](#application-deployment)
6. [Security Hardening](#security-hardening)
7. [Monitoring and Observability](#monitoring-and-observability)
8. [Backup and Disaster Recovery](#backup-and-disaster-recovery)
9. [Scaling and Performance](#scaling-and-performance)
10. [Troubleshooting](#troubleshooting)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Azure AKS Cluster                     │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Ingress    │  │   Ingress    │  │   Ingress    │ │
│  │  Controller  │  │  Controller  │  │  Controller  │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                 │          │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐ │
│  │ Vote Service │  │Result Service│  │Worker Service│ │
│  │  (Python)    │  │  (Node.js)   │  │   (.NET)     │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                 │          │
│         └────────┬────────┴────────┬─────────┘          │
│                  │               │                     │
│         ┌────────▼──────┐  ┌─────▼─────────┐          │
│         │     Redis     │  │  PostgreSQL   │          │
│         │   (Cache)     │  │  (Database)   │          │
│         └──────────────┘  └───────────────┘          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Components

- **Vote Service**: Python/Flask frontend for voting
- **Result Service**: Node.js frontend for viewing results
- **Worker Service**: C#/.NET background worker processing votes
- **PostgreSQL**: Primary database (via Bitnami Helm chart)
- **Redis**: Cache and message queue (via Bitnami Helm chart)
- **NGINX Ingress**: External access and SSL termination

## Prerequisites

### Required Tools

1. **Terraform** >= 1.0
   ```bash
   terraform version
   ```

2. **Azure CLI** with active subscription
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

3. **kubectl** >= 1.28
   ```bash
   kubectl version --client
   ```

4. **Helm** >= 3.0
   ```bash
   helm version
   ```

5. **Docker** for building images
   ```bash
   docker --version
   ```

### Azure Resources

- Active Azure subscription
- Contributor role on subscription
- Resource group creation permissions

## Infrastructure Provisioning

### Step 1: Configure Terraform

1. **Navigate to Terraform directory**
   ```bash
   cd terraform
   ```

2. **Review production variables**
   ```bash
   cat prod.tfvars
   ```

3. **Update production variables** (if needed)
   ```bash
   # Edit prod.tfvars
   project_name = "voting-app"
   environment  = "prod"
   deploy_to_azure = true
   node_count = 3
   min_node_count = 2
   max_node_count = 10
   node_vm_size = "Standard_D2s_v3"
   ```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Create Workspace

```bash
# Create production workspace
terraform workspace new prod
terraform workspace select prod
```

### Step 4: Plan Infrastructure

```bash
terraform plan -var-file=prod.tfvars
```

Review the plan carefully:
- Resource group creation
- Virtual network and subnet
- Network Security Group rules
- AKS cluster configuration
- Azure Container Registry
- Ingress controller
- PostgreSQL and Redis via Helm

### Step 5: Apply Infrastructure

```bash
terraform apply -var-file=prod.tfvars
```

This will create:
- ✅ Resource group
- ✅ Virtual network with subnet
- ✅ Network Security Group
- ✅ Azure Container Registry
- ✅ AKS cluster with networking
- ✅ NGINX Ingress Controller
- ✅ PostgreSQL (via Bitnami Helm)
- ✅ Redis (via Bitnami Helm)

**Expected time**: 15-20 minutes

### Step 6: Get Outputs

```bash
terraform output
```

Save the following:
- `acr_login_server` - For pushing images
- `aks_cluster_name` - For cluster operations
- `cluster_endpoint` - Kubernetes API endpoint

## Secrets Management

### Production-Grade Secrets

**Never store secrets in code or version control!**

### Option 1: Azure Key Vault (Recommended)

1. **Create Key Vault**
   ```bash
   az keyvault create \
     --name voting-app-kv \
     --resource-group <resource-group> \
     --location <location>
   ```

2. **Store Secrets**
   ```bash
   # Generate secure password
   POSTGRES_PASSWORD=$(openssl rand -base64 32)
   
   # Store in Key Vault
   az keyvault secret set \
     --vault-name voting-app-kv \
     --name postgres-password \
     --value "$POSTGRES_PASSWORD"
   ```

3. **Install Azure Key Vault Provider**
   ```bash
   # Add Helm repo
   helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
   
   # Install
   helm install csi-secrets-store-provider-azure \
     csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
     --namespace kube-system
   ```

4. **Update Helm Values**
   ```yaml
   secrets:
     useExternalSecret: true
     externalSecretProvider: "azure-keyvault"
   ```

### Option 2: External Secrets Operator

1. **Install External Secrets Operator**
   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets \
     external-secrets/external-secrets \
     -n external-secrets-system \
     --create-namespace
   ```

2. **Configure SecretStore**
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: SecretStore
   metadata:
     name: azure-keyvault
   spec:
     provider:
       azurekv:
         vaultUrl: "https://voting-app-kv.vault.azure.net"
         authType: "ManagedIdentity"
   ```

### Option 3: Sealed Secrets (Alternative)

For GitOps workflows:
```bash
# Install Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

## Application Deployment

### Step 1: Build and Push Images

1. **Login to ACR**
   ```bash
   ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
   az acr login --name $(terraform output -raw acr_name)
   ```

2. **Build Images**
   ```bash
   # Vote service
   cd ../vote
   docker build -t $ACR_LOGIN_SERVER/vote:v2 .
   docker push $ACR_LOGIN_SERVER/vote:v2
   
   # Result service
   cd ../result
   docker build -t $ACR_LOGIN_SERVER/result:v2 .
   docker push $ACR_LOGIN_SERVER/result:v2
   
   # Worker service
   cd ../worker
   docker build -t $ACR_LOGIN_SERVER/worker:v2 .
   docker push $ACR_LOGIN_SERVER/worker:v2
   ```

### Step 2: Configure Helm Values

1. **Update values-aks.yaml**
   ```bash
   cd ../helm/voting-app
   
   # Replace ACR name
   sed -i "s|<ACR_NAME>|$ACR_LOGIN_SERVER|g" values-aks.yaml
   ```

2. **Update Production Values**
   ```yaml
   # values-aks.yaml
   global:
     imageRegistry: "<ACR_NAME>.azurecr.io"
   
   vote:
     replicaCount: 3
     resources:
       requests:
         memory: "256Mi"
         cpu: "200m"
       limits:
         memory: "512Mi"
         cpu: "1000m"
   
   result:
     replicaCount: 3
     resources:
       requests:
         memory: "256Mi"
         cpu: "200m"
       limits:
         memory: "512Mi"
         cpu: "1000m"
   
   worker:
     replicaCount: 3
   
   postgresql:
     persistence:
       size: 50Gi
     resources:
       requests:
         memory: "512Mi"
         cpu: "500m"
       limits:
         memory: "2Gi"
         cpu: "2000m"
   
   networkPolicy:
     enabled: true
     databaseIsolation: true
   
   podDisruptionBudget:
     enabled: true
     minAvailable: 2
   ```

### Step 3: Deploy with Helm

```bash
# Install/Upgrade
helm upgrade --install voting-app . \
  --namespace voting-app \
  --create-namespace \
  --values values-aks.yaml \
  --values values-prod.yaml \
  --wait \
  --timeout 10m
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n voting-app

# Check services
kubectl get services -n voting-app

# Check ingress
kubectl get ingress -n voting-app

# Check Helm release
helm status voting-app -n voting-app
```

## Security Hardening

### 1. Pod Security Standards (PSA)

Already configured in namespace:
```yaml
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

### 2. Network Policies

Enabled and configured:
- ✅ Database isolation (PostgreSQL only accessible from worker/result)
- ✅ Redis isolation (only accessible from vote/worker)
- ✅ Frontend ingress rules

Verify:
```bash
kubectl get networkpolicies -n voting-app
```

### 3. Non-Root Containers

All containers run as non-root:
- Vote: UID 1000
- Result: UID 1000
- Worker: UID 1000
- PostgreSQL: UID 999
- Redis: UID 999

### 4. Resource Limits

All pods have resource limits:
```bash
kubectl describe pod <pod-name> -n voting-app | grep -A 5 "Limits"
```

### 5. TLS/HTTPS

Configure TLS in ingress:
```yaml
ingress:
  tls:
    - secretName: voting-app-tls-secret
      hosts:
        - voting-app.yourdomain.com
```

## Monitoring and Observability

### Azure Monitor

1. **Enable Azure Monitor** (if not enabled)
   ```bash
   az aks enable-addons \
     --resource-group <rg> \
     --name <cluster-name> \
     --addons monitoring
   ```

2. **View Logs**
   ```bash
   az aks get-credentials --resource-group <rg> --name <cluster-name>
   kubectl logs -f deployment/voting-app-vote -n voting-app
   ```

### Application Insights

1. **Create Application Insights**
   ```bash
   az monitor app-insights component create \
     --app voting-app-insights \
     --location <location> \
     --resource-group <rg>
   ```

2. **Get Instrumentation Key**
   ```bash
   az monitor app-insights component show \
     --app voting-app-insights \
     --resource-group <rg> \
     --query instrumentationKey
   ```

## Backup and Disaster Recovery

### PostgreSQL Backup

1. **Enable Automated Backups** (Azure Database for PostgreSQL recommended)
2. **Manual Backup**
   ```bash
   kubectl exec -it <postgres-pod> -n voting-app -- \
     pg_dump -U postgres postgres > backup.sql
   ```

### Redis Backup

1. **Enable Persistence** (already configured in production)
2. **Manual Snapshot**
   ```bash
   kubectl exec -it <redis-pod> -n voting-app -- redis-cli BGSAVE
   ```

## Scaling and Performance

### Horizontal Pod Autoscaler

```bash
# Vote service
kubectl autoscale deployment voting-app-vote \
  -n voting-app \
  --cpu-percent=70 \
  --min=3 \
  --max=10

# Result service
kubectl autoscale deployment voting-app-result \
  -n voting-app \
  --cpu-percent=70 \
  --min=3 \
  --max=10

# Worker service
kubectl autoscale deployment voting-app-worker \
  -n voting-app \
  --cpu-percent=70 \
  --min=2 \
  --max=5
```

### Cluster Autoscaler

Already enabled in Terraform:
```hcl
enable_auto_scaling = true
min_node_count = 2
max_node_count = 10
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod
kubectl describe pod <pod-name> -n voting-app

# Check logs
kubectl logs <pod-name> -n voting-app

# Check events
kubectl get events -n voting-app --sort-by='.lastTimestamp'
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl get pods -l app=postgres -n voting-app

# Test connection
kubectl exec -it <postgres-pod> -n voting-app -- \
  psql -U postgres -d postgres -c "SELECT 1;"
```

### Network Policy Issues

```bash
# Check network policies
kubectl get networkpolicies -n voting-app

# Describe policy
kubectl describe networkpolicy <policy-name> -n voting-app

# Temporarily disable (for debugging)
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml \
  --set networkPolicy.enabled=false
```

## Next Steps

1. ✅ **Set up CI/CD** pipeline
2. ✅ **Configure monitoring alerts**
3. ✅ **Set up backup automation**
4. ✅ **Implement blue-green deployments**
5. ✅ **Configure disaster recovery procedures**

## Support

For issues:
- Check [terraform/README.md](./terraform/README.md)
- Check [aks/HELM_DEPLOYMENT_GUIDE.md](./aks/HELM_DEPLOYMENT_GUIDE.md)
- Review Kubernetes logs
- Check Azure portal for resource status

