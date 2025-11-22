# Helm Quick Start Guide - AKS Deployment

This is a condensed quick start guide for Helm deployment. For detailed instructions, see [HELM_DEPLOYMENT_GUIDE.md](./HELM_DEPLOYMENT_GUIDE.md).

## Prerequisites Check

```bash
# Check Azure CLI
az --version

# Check kubectl
kubectl version --client

# Check Helm
helm version

# Check Docker
docker --version

# Login to Azure
az login
```

## Step 1: Set Variables

```bash
RESOURCE_GROUP="voting-app-rg"
LOCATION="eastus"
AKS_CLUSTER_NAME="voting-app-aks"
ACR_NAME="votingapp$(openssl rand -hex 3)"
```

## Step 2: Create Azure Resources

```bash
# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

# Create AKS cluster (takes 10-15 minutes)
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --node-count 3 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --attach-acr $ACR_NAME \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing
```

## Step 3: Build and Push Images

```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv)

# Login to ACR
az acr login --name $ACR_NAME

# Build and push images
cd ../vote && docker build -t $ACR_LOGIN_SERVER/vote:v2 . && docker push $ACR_LOGIN_SERVER/vote:v2
cd ../result && docker build -t $ACR_LOGIN_SERVER/result:v2 . && docker push $ACR_LOGIN_SERVER/result:v2
cd ../worker && docker build -t $ACR_LOGIN_SERVER/worker:v2 . && docker push $ACR_LOGIN_SERVER/worker:v2
cd ../helm/voting-app
```

## Step 4: Update Helm Values

```bash
# Replace <ACR_NAME> in values-aks.yaml
sed -i "s|<ACR_NAME>|$ACR_LOGIN_SERVER|g" values-aks.yaml
```

**Windows PowerShell:**
```powershell
$ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv
(Get-Content values-aks.yaml) -replace '<ACR_NAME>', $ACR_LOGIN_SERVER | Set-Content values-aks.yaml
```

## Step 5: Deploy with Helm

```bash
# Install the chart
helm install voting-app . \
  --namespace voting-app \
  --create-namespace \
  --values values-aks.yaml

# Verify installation
helm list -n voting-app
kubectl get pods -n voting-app
```

## Step 6: Upgrade/Update

```bash
# Upgrade with new values
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml

# Scale a service
helm upgrade voting-app . \
  --namespace voting-app \
  --values values-aks.yaml \
  --set vote.replicaCount=3
```

## Step 7: Access the Application

### Option A: Port Forwarding

```bash
# Vote service
kubectl port-forward service/voting-app-vote 8080:80 -n voting-app

# Result service
kubectl port-forward service/voting-app-result 8081:4000 -n voting-app
```

Access:
- Vote: http://localhost:8080
- Result: http://localhost:8081

### Option B: LoadBalancer Services

```bash
kubectl expose deployment voting-app-vote -n voting-app --type=LoadBalancer --port=80 --target-port=80 --name=vote-lb
kubectl expose deployment voting-app-result -n voting-app --type=LoadBalancer --port=4000 --target-port=4000 --name=result-lb
kubectl get services -n voting-app
```

### Option C: NGINX Ingress

```bash
# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Update values-aks.yaml ingress configuration, then upgrade
helm upgrade voting-app . --namespace voting-app --values values-aks.yaml

# Get ingress IP
kubectl get service ingress-nginx-controller -n ingress-nginx
```

## Common Commands

```bash
# View Helm releases
helm list -n voting-app

# Check release status
helm status voting-app -n voting-app

# View all resources
kubectl get all -n voting-app

# View pod logs
kubectl logs -f deployment/voting-app-vote -n voting-app

# Rollback to previous version
helm rollback voting-app <revision-number> -n voting-app

# Uninstall
helm uninstall voting-app -n voting-app
```

## Troubleshooting

```bash
# Pod not starting?
kubectl describe pod <pod-name> -n voting-app
kubectl logs <pod-name> -n voting-app

# Check Helm release
helm status voting-app -n voting-app
helm get manifest voting-app -n voting-app

# Rollback
helm rollback voting-app -n voting-app
```

## Cleanup

```bash
# Uninstall Helm release
helm uninstall voting-app -n voting-app

# Delete namespace
kubectl delete namespace voting-app

# Delete AKS cluster
az aks delete --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --yes

# Delete ACR
az acr delete --resource-group $RESOURCE_GROUP --name $ACR_NAME --yes

# Delete resource group
az group delete --name $RESOURCE_GROUP --yes
```

## Next Steps

- Read [HELM_DEPLOYMENT_GUIDE.md](./HELM_DEPLOYMENT_GUIDE.md) for detailed instructions
- Review production considerations
- Set up monitoring and logging
- Configure backup and disaster recovery

