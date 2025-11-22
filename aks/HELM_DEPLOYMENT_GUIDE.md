# Helm Deployment Guide for AKS

This guide provides step-by-step instructions to deploy the Voting Application on Azure Kubernetes Service (AKS) using Helm.

## Prerequisites

1. **Azure CLI** installed and configured
   ```bash
   az --version
   az login
   ```

2. **kubectl** installed
   ```bash
   kubectl version --client
   ```

3. **Helm 3** installed
   ```bash
   helm version
   ```

4. **Docker** installed (for building images)

5. **Azure Subscription** with appropriate permissions

6. **Azure Container Registry (ACR)** - We'll create this in the guide

## Architecture Overview

The Voting Application consists of:
- **Vote Service** (Python/Flask) - Frontend for voting
- **Result Service** (Node.js) - Frontend for viewing results
- **Worker Service** (C#/.NET) - Background worker processing votes
- **PostgreSQL** - Database for storing votes
- **Redis** - Cache/Message queue

## Step 1: Create Azure Resources

### 1.1 Set Variables

```bash
# Set your variables
RESOURCE_GROUP="voting-app-rg"
LOCATION="eastus"  # Change to your preferred region
AKS_CLUSTER_NAME="voting-app-aks"
ACR_NAME="votingapp$(openssl rand -hex 3)"  # ACR name must be globally unique
NODE_COUNT=3
NODE_VM_SIZE="Standard_B2s"  # Adjust based on your needs
```

### 1.2 Create Resource Group

```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 1.3 Create Azure Container Registry (ACR)

```bash
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true
```

### 1.4 Create AKS Cluster

```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_VM_SIZE \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys
```

**Note:** This may take 10-15 minutes to complete.

### 1.5 Get AKS Credentials

```bash
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --overwrite-existing
```

### 1.6 Verify Cluster Connection

```bash
kubectl get nodes
```

## Step 2: Build and Push Docker Images

### 2.1 Login to ACR

```bash
az acr login --name $ACR_NAME
```

### 2.2 Build and Push Images

```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv)

# Build and push Vote service
cd ../vote
docker build -t $ACR_LOGIN_SERVER/vote:v2 .
docker push $ACR_LOGIN_SERVER/vote:v2

# Build and push Result service
cd ../result
docker build -t $ACR_LOGIN_SERVER/result:v2 .
docker push $ACR_LOGIN_SERVER/result:v2

# Build and push Worker service
cd ../worker
docker build -t $ACR_LOGIN_SERVER/worker:v2 .
docker push $ACR_LOGIN_SERVER/worker:v2

cd ../helm/voting-app
```

## Step 3: Configure Helm Values

### 3.1 Update AKS Values File

Edit `values-aks.yaml` and replace `<ACR_NAME>` with your ACR login server:

```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv)

# Update values-aks.yaml (Linux/Mac)
sed -i "s|<ACR_NAME>|$ACR_LOGIN_SERVER|g" values-aks.yaml

# Windows PowerShell
$ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv
(Get-Content values-aks.yaml) -replace '<ACR_NAME>', $ACR_LOGIN_SERVER | Set-Content values-aks.yaml
```

**Or manually edit `values-aks.yaml`:**
- Replace `<ACR_NAME>.azurecr.io` with your actual ACR login server (e.g., `myregistry.azurecr.io`)

### 3.2 (Optional) Create Image Pull Secret

If AKS is not attached to ACR, create an image pull secret:

```bash
# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv)

# Create Kubernetes secret
kubectl create secret docker-registry acr-secret \
  --docker-server=$ACR_LOGIN_SERVER \
  --docker-username=$ACR_USERNAME \
  --docker-password=$ACR_PASSWORD \
  --namespace voting-app

# Update values-aks.yaml to use the secret
# Set: global.imagePullSecrets: ["acr-secret"]
```

## Step 4: Deploy with Helm

### 4.1 Install the Chart

```bash
# From the helm/voting-app directory
helm install voting-app . \
  --namespace voting-app \
  --create-namespace \
  --values values-aks.yaml
```

### 4.2 Verify Installation

```bash
# Check Helm release
helm list -n voting-app

# Check pods
kubectl get pods -n voting-app

# Check services
kubectl get services -n voting-app

# Check deployments
kubectl get deployments -n voting-app
```

### 4.3 Check Release Status

```bash
helm status voting-app -n voting-app
```

## Step 5: Upgrade/Update Deployment

### 5.1 Upgrade with New Values

```bash
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml
```

### 5.2 Upgrade with Specific Value Override

```bash
# Example: Scale vote service to 3 replicas
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml \
  --set vote.replicaCount=3
```

### 5.3 Upgrade After Image Update

After pushing new images to ACR:

```bash
# Upgrade with new image tag
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml \
  --set vote.image.tag=v3 \
  --set result.image.tag=v3 \
  --set worker.image.tag=v3
```

## Step 6: Expose the Application

### Option A: Using LoadBalancer Services

```bash
# Expose Vote service
kubectl expose deployment voting-app-vote \
  --namespace voting-app \
  --type=LoadBalancer \
  --port=80 \
  --target-port=80 \
  --name=vote-lb

# Expose Result service
kubectl expose deployment voting-app-result \
  --namespace voting-app \
  --type=LoadBalancer \
  --port=4000 \
  --target-port=4000 \
  --name=result-lb

# Get external IPs
kubectl get services -n voting-app
```

### Option B: Using NGINX Ingress Controller (Recommended)

#### 6.1 Install NGINX Ingress Controller

```bash
# Add NGINX Ingress Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

#### 6.2 Update Ingress Configuration

Edit `values-aks.yaml` to configure ingress:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
    - host: voting-app.yourdomain.com  # Change to your domain
      paths:
        - path: /vote
          pathType: Prefix
        - path: /result
          pathType: Prefix
```

#### 6.3 Upgrade Helm Release

```bash
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml
```

#### 6.4 Get Ingress IP

```bash
# Wait for LoadBalancer IP
kubectl get service ingress-nginx-controller -n ingress-nginx

# Get the EXTERNAL-IP (this may take a few minutes)
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

## Step 7: Verify Deployment

### 7.1 Check Pod Status

```bash
kubectl get pods -n voting-app -o wide
```

All pods should be in `Running` state.

### 7.2 Check Logs

```bash
# Check Vote service logs
kubectl logs -f deployment/voting-app-vote -n voting-app

# Check Result service logs
kubectl logs -f deployment/voting-app-result -n voting-app

# Check Worker logs
kubectl logs -f deployment/voting-app-worker -n voting-app
```

### 7.3 Test the Application

1. Access the Vote service and cast votes
2. Access the Result service to see the results
3. Verify votes are being processed by checking worker logs

## Step 8: Scaling

### 8.1 Manual Scaling

```bash
# Scale Vote service
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml \
  --set vote.replicaCount=3

# Scale Result service
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml \
  --set result.replicaCount=3

# Scale Worker
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml \
  --set worker.replicaCount=3
```

### 8.2 Auto-scaling (HPA)

Create Horizontal Pod Autoscaler:

```bash
kubectl autoscale deployment voting-app-vote -n voting-app --cpu-percent=70 --min=2 --max=10
kubectl autoscale deployment voting-app-result -n voting-app --cpu-percent=70 --min=2 --max=10
kubectl autoscale deployment voting-app-worker -n voting-app --cpu-percent=70 --min=2 --max=10
```

## Step 9: Monitoring and Troubleshooting

### 9.1 View Resource Usage

```bash
kubectl top pods -n voting-app
kubectl top nodes
```

### 9.2 Describe Resources

```bash
# Describe a pod
kubectl describe pod <pod-name> -n voting-app

# Describe a deployment
kubectl describe deployment voting-app-vote -n voting-app

# Describe Helm release
helm get manifest voting-app -n voting-app
```

### 9.3 Common Issues

**Pods not starting:**
```bash
kubectl describe pod <pod-name> -n voting-app
kubectl logs <pod-name> -n voting-app
```

**Image pull errors:**
- Verify ACR credentials
- Check image names in values file
- Ensure AKS has access to ACR

**Database connection issues:**
- Verify PostgreSQL pod is running
- Check connection strings in secrets
- Verify network policies

**Helm upgrade issues:**
```bash
# Check release history
helm history voting-app -n voting-app

# Rollback to previous version
helm rollback voting-app <revision-number> -n voting-app
```

## Step 10: Production Considerations

### 10.1 Use Production Values

```bash
# Use production values file
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-prod.yaml \
  --values values-aks.yaml
```

### 10.2 Use Azure Key Vault for Secrets

```bash
# Install Azure Key Vault Provider for Secrets Store CSI Driver
# See: https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver
```

### 10.3 Enable Azure Monitor

```bash
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --addons monitoring
```

### 10.4 Use Azure Database for PostgreSQL

For production, consider using Azure Database for PostgreSQL instead of in-cluster PostgreSQL.

### 10.5 Use Azure Cache for Redis

For production, consider using Azure Cache for Redis instead of in-cluster Redis.

### 10.6 Enable HTTPS/TLS

- Configure TLS certificates in ingress
- Use Azure Key Vault for certificate management
- Enable HTTPS redirect

## Step 11: Uninstall

### 11.1 Uninstall Helm Release

```bash
helm uninstall voting-app -n voting-app
```

### 11.2 Delete Namespace (Optional)

```bash
kubectl delete namespace voting-app
```

## Quick Reference Commands

```bash
# Get ACR login server
az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Install Helm chart
helm install voting-app . --namespace voting-app --create-namespace --values values-aks.yaml

# Upgrade Helm chart
helm upgrade voting-app . --namespace voting-app --values values-aks.yaml

# Check Helm release
helm list -n voting-app
helm status voting-app -n voting-app

# View pods
kubectl get pods -n voting-app

# View services
kubectl get services -n voting-app

# View logs
kubectl logs -f deployment/voting-app-vote -n voting-app

# Port forward for local testing
kubectl port-forward service/voting-app-vote 8080:80 -n voting-app
kubectl port-forward service/voting-app-result 8081:4000 -n voting-app

# Rollback Helm release
helm rollback voting-app <revision-number> -n voting-app

# Uninstall Helm release
helm uninstall voting-app -n voting-app
```

## Support

For issues or questions:
1. Check pod logs: `kubectl logs <pod-name> -n voting-app`
2. Describe resources: `kubectl describe <resource> <name> -n voting-app`
3. Check Helm release: `helm status voting-app -n voting-app`
4. Check Azure portal for AKS cluster status
5. Review Azure documentation for AKS troubleshooting

