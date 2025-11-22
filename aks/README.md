# AKS Deployment Files

This directory contains Kubernetes manifests and deployment scripts for deploying the Voting Application to Azure Kubernetes Service (AKS).

## Files Overview

### Kubernetes Manifests

- **namespace.yaml** - Creates the `voting-app` namespace
- **configmap.yaml** - Application configuration (options, ports, etc.)
- **secret.yaml** - Sensitive data (database passwords, connection strings)
- **vote-deployment.yaml** - Vote service deployment
- **vote-service.yaml** - Vote service ClusterIP service
- **result-deployment.yaml** - Result service deployment
- **result-service.yaml** - Result service ClusterIP service
- **worker-deployment.yaml** - Worker service deployment
- **postgres-deployment.yaml** - PostgreSQL StatefulSet
- **postgres-service.yaml** - PostgreSQL service
- **redis-deployment.yaml** - Redis deployment
- **redis-service.yaml** - Redis service
- **ingress.yaml** - Ingress for Application Gateway
- **ingress-nginx.yaml** - Ingress for NGINX Ingress Controller
- **image-pull-secret.yaml** - Template for ACR pull secret
- **kustomization.yaml** - Kustomize configuration

### Deployment Scripts

- **deploy.sh** - Bash script for Linux/Mac deployment automation (kubectl)
- **deploy.ps1** - PowerShell script for Windows deployment automation (kubectl)
- **deploy-helm.sh** - Bash script for Linux/Mac Helm deployment automation
- **deploy-helm.ps1** - PowerShell script for Windows Helm deployment automation
- **DEPLOYMENT_GUIDE.md** - Comprehensive step-by-step deployment guide (kubectl)
- **HELM_DEPLOYMENT_GUIDE.md** - Comprehensive Helm deployment guide
- **HELM_QUICK_START.md** - Quick start guide for Helm deployment

## Quick Start

### Prerequisites

1. Azure CLI installed and logged in
2. kubectl installed
3. Docker installed
4. Azure subscription with appropriate permissions

### Option 1: Helm Deployment (Recommended)

Helm provides better management, versioning, and configuration management.

#### Linux/Mac:

```bash
cd ../helm/voting-app
chmod +x ../../aks/deploy-helm.sh
../../aks/deploy-helm.sh
```

Or manually:

```bash
cd ../helm/voting-app
# Update values-aks.yaml with your ACR name
helm install voting-app . --namespace voting-app --create-namespace --values values-aks.yaml
```

#### Windows:

```powershell
cd ..\helm\voting-app
..\..\aks\deploy-helm.ps1
```

See [HELM_DEPLOYMENT_GUIDE.md](./HELM_DEPLOYMENT_GUIDE.md) or [HELM_QUICK_START.md](./HELM_QUICK_START.md) for detailed instructions.

### Option 2: kubectl Deployment

#### Linux/Mac:

```bash
chmod +x deploy.sh
./deploy.sh
```

#### Windows:

```powershell
.\deploy.ps1
```

### Option 3: Manual Deployment

Follow the detailed instructions in [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)

## Quick Reference

### Before Deployment

1. **Update ACR name** in deployment files:

   - `vote-deployment.yaml`
   - `result-deployment.yaml`
   - `worker-deployment.yaml`

   Replace `<ACR_NAME>` with your Azure Container Registry login server.

2. **Update secrets** in `secret.yaml` for production use.

### Deploy All Resources

```bash
kubectl apply -k .
```

Or deploy individually:

```bash
# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Create config and secrets
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

# 3. Deploy databases
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f redis-service.yaml

# 4. Wait for databases
kubectl wait --for=condition=ready pod -l app=postgres -n voting-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n voting-app --timeout=300s

# 5. Deploy application
kubectl apply -f worker-deployment.yaml
kubectl apply -f vote-deployment.yaml
kubectl apply -f vote-service.yaml
kubectl apply -f result-deployment.yaml
kubectl apply -f result-service.yaml

# 6. Deploy ingress (optional)
kubectl apply -f ingress-nginx.yaml
```

### Check Status

```bash
# View all resources
kubectl get all -n voting-app

# View pods
kubectl get pods -n voting-app

# View services
kubectl get services -n voting-app

# View logs
kubectl logs -f deployment/vote -n voting-app
```

### Access the Application

#### Using Port Forwarding (for testing):

```bash
# Vote service
kubectl port-forward service/vote 8080:80 -n voting-app

# Result service
kubectl port-forward service/result 8081:4000 -n voting-app
```

Then access:

- Vote: http://localhost:8080
- Result: http://localhost:8081

#### Using LoadBalancer:

```bash
# Create LoadBalancer services
kubectl expose deployment vote -n voting-app --type=LoadBalancer --port=80 --target-port=80 --name=vote-lb
kubectl expose deployment result -n voting-app --type=LoadBalancer --port=4000 --target-port=4000 --name=result-lb

# Get external IPs
kubectl get services -n voting-app
```

#### Using Ingress:

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for ingress setup instructions.

## Important Notes

1. **ACR Integration**: The deployment files reference Azure Container Registry (ACR). Make sure to:

   - Build and push images to ACR
   - Update `<ACR_NAME>` placeholders in deployment files
   - Ensure AKS has access to ACR (use `--attach-acr` when creating AKS)

2. **Secrets**: The default secrets in `secret.yaml` are for development only. For production:

   - Use Azure Key Vault
   - Generate strong passwords
   - Never commit secrets to version control

3. **Storage**: PostgreSQL uses PersistentVolumeClaims. The storage class `managed-csi` is used (default for AKS). Adjust if needed.

4. **Resource Limits**: Adjust CPU and memory limits in deployment files based on your workload requirements.

5. **Scaling**: Use `kubectl scale` or Horizontal Pod Autoscaler (HPA) for automatic scaling.

## Troubleshooting

See the [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for detailed troubleshooting steps.

Common issues:

- **Image pull errors**: Check ACR credentials and image names
- **Pod not starting**: Check logs with `kubectl logs <pod-name> -n voting-app`
- **Database connection issues**: Verify PostgreSQL pod is running and check connection strings

## Production Considerations

1. Use Azure Database for PostgreSQL instead of in-cluster PostgreSQL
2. Use Azure Cache for Redis instead of in-cluster Redis
3. Enable Azure Monitor for AKS
4. Use Azure Key Vault for secrets management
5. Configure TLS/HTTPS for ingress
6. Set up network policies
7. Enable pod security policies
8. Configure backup and disaster recovery

## Deployment Methods

### Helm (Recommended)

Helm provides:

- Better configuration management with values files
- Easy upgrades and rollbacks
- Template-based manifests
- Version control for releases

**Quick Start:**

```bash
cd ../helm/voting-app
helm install voting-app . --namespace voting-app --create-namespace --values values-aks.yaml
```

See [HELM_DEPLOYMENT_GUIDE.md](./HELM_DEPLOYMENT_GUIDE.md) for complete instructions.

### kubectl

Direct Kubernetes manifest deployment:

- Full control over individual resources
- No additional tooling required
- Good for learning Kubernetes

**Quick Start:**

```bash
kubectl apply -k .
```

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for complete instructions.

## Support

For detailed instructions:

- **Helm**: See [HELM_DEPLOYMENT_GUIDE.md](./HELM_DEPLOYMENT_GUIDE.md) or [HELM_QUICK_START.md](./HELM_QUICK_START.md)
- **kubectl**: See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) or [QUICK_START.md](./QUICK_START.md)
