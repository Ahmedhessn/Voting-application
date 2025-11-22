# Local Kubernetes Cluster Setup Guide

This guide provides instructions for setting up local Kubernetes clusters (minikube, k3s, microk8s) for developing and testing the Voting Application.

## Overview

Local Kubernetes clusters are ideal for:
- ✅ Development and testing
- ✅ Learning Kubernetes
- ✅ Quick prototyping
- ✅ CI/CD pipeline testing
- ✅ Cost-free development

## Prerequisites

- **Docker** installed (for minikube)
- **VirtualBox** or **Hyper-V** (for minikube on Windows)
- **Linux** (for k3s and microk8s)
- **kubectl** installed
- **Helm 3** installed

## Option 1: minikube

### Installation

**Windows:**
```powershell
# Using Chocolatey
choco install minikube

# Or download from: https://minikube.sigs.k8s.io/docs/start/
```

**Linux:**
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

**macOS:**
```bash
brew install minikube
```

### Start minikube

```bash
# Start with default settings
minikube start

# Start with specific resources
minikube start --memory=4096 --cpus=2

# Start with specific driver
minikube start --driver=virtualbox
# or
minikube start --driver=hyperv  # Windows
# or
minikube start --driver=docker
```

### Enable Add-ons

```bash
# Enable ingress
minikube addons enable ingress

# Enable storage provisioner
minikube addons enable storage-provisioner

# Enable metrics server
minikube addons enable metrics-server

# List all add-ons
minikube addons list
```

### Configure kubectl

```bash
# Get minikube kubeconfig
minikube kubectl -- get nodes

# Or use minikube's kubectl
eval $(minikube docker-env)
```

### Deploy Application

```bash
# Set Terraform to use local cluster
cd terraform
terraform apply -var-file=dev.tfvars \
  -var="deploy_to_azure=false" \
  -var="local_kubeconfig_path=$HOME/.kube/config" \
  -var="local_kubeconfig_context=minikube"
```

### Access Application

```bash
# Get minikube IP
minikube ip

# Use port-forwarding
kubectl port-forward service/vote 8080:80 -n voting-app
kubectl port-forward service/result 8081:4000 -n voting-app

# Or use minikube service
minikube service vote -n voting-app
minikube service result -n voting-app
```

### Stop/Delete minikube

```bash
# Stop minikube
minikube stop

# Delete minikube
minikube delete
```

## Option 2: k3s

### Installation (Linux)

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Check status
sudo systemctl status k3s

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config
```

### Enable Ingress

```bash
# k3s comes with Traefik ingress by default
# Or install NGINX ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### Enable Storage

```bash
# k3s uses local-path-provisioner by default
# Verify storage class
kubectl get storageclass
```

### Deploy Application

```bash
cd terraform
terraform apply -var-file=dev.tfvars \
  -var="deploy_to_azure=false" \
  -var="local_kubeconfig_path=$HOME/.kube/k3s-config" \
  -var="local_kubeconfig_context=default"
```

### Access Application

```bash
# Get node IP
kubectl get nodes -o wide

# Use port-forwarding
kubectl port-forward service/vote 8080:80 -n voting-app

# Or use ingress (if configured)
curl http://<node-ip>/vote
```

### Uninstall k3s

```bash
# Uninstall k3s
/usr/local/bin/k3s-uninstall.sh
```

## Option 3: microk8s

### Installation (Linux - Ubuntu/Debian)

```bash
# Install microk8s
sudo snap install microk8s --classic

# Add user to microk8s group
sudo usermod -a -G microk8s $USER
newgrp microk8s

# Check status
microk8s status --wait-ready
```

### Enable Add-ons

```bash
# Enable DNS
microk8s enable dns

# Enable storage
microk8s enable storage

# Enable ingress
microk8s enable ingress

# Enable metrics
microk8s enable metrics-server

# List enabled add-ons
microk8s status
```

### Configure kubectl

```bash
# Get kubeconfig
microk8s config > ~/.kube/microk8s-config
export KUBECONFIG=~/.kube/microk8s-config

# Or use microk8s kubectl
microk8s kubectl get nodes
```

### Deploy Application

```bash
cd terraform
terraform apply -var-file=dev.tfvars \
  -var="deploy_to_azure=false" \
  -var="local_kubeconfig_path=$HOME/.kube/microk8s-config" \
  -var="local_kubeconfig_context=microk8s"
```

### Access Application

```bash
# Get node IP
microk8s kubectl get nodes -o wide

# Use port-forwarding
microk8s kubectl port-forward service/vote 8080:80 -n voting-app

# Or use ingress
curl http://localhost/vote
```

### Uninstall microk8s

```bash
# Uninstall microk8s
sudo snap remove microk8s
```

## Comparison Table

| Feature | minikube | k3s | microk8s |
|---------|----------|-----|----------|
| **OS Support** | Windows, Linux, macOS | Linux | Linux (Ubuntu/Debian) |
| **Resource Usage** | Medium | Low | Low |
| **Startup Time** | 1-2 minutes | 10-30 seconds | 30-60 seconds |
| **Storage** | Manual setup | Local-path | HostPath |
| **Ingress** | Add-on | Traefik (built-in) | NGINX (add-on) |
| **Multi-node** | Limited | Yes | Yes |
| **Production Use** | No | Limited | No |

## Common Issues and Solutions

### Issue: Cannot connect to cluster

**Solution:**
```bash
# Check cluster status
kubectl cluster-info

# Verify kubeconfig
kubectl config view

# Check context
kubectl config current-context
```

### Issue: Storage not working

**Solution:**
```bash
# For minikube
minikube addons enable storage-provisioner

# For k3s (already enabled)
kubectl get storageclass

# For microk8s
microk8s enable storage
```

### Issue: Ingress not working

**Solution:**
```bash
# For minikube
minikube addons enable ingress
minikube addons list

# For k3s (Traefik is default)
kubectl get ingressclass

# For microk8s
microk8s enable ingress
```

### Issue: Images not pulling

**Solution:**
```bash
# For minikube - use minikube's Docker
eval $(minikube docker-env)
docker build -t vote:v2 ../vote

# For k3s/microk8s - use local registry or public images
# Or configure image pull secrets
```

## Development Workflow

### 1. Start Local Cluster

```bash
# Choose your cluster
minikube start
# or
# k3s is already running
# or
microk8s status --wait-ready
```

### 2. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply -var-file=dev.tfvars \
  -var="deploy_to_azure=false"
```

### 3. Build and Push Images

```bash
# For minikube
eval $(minikube docker-env)
docker build -t vote:v2 ../vote
docker build -t result:v2 ../result
docker build -t worker:v2 ../worker

# For k3s/microk8s - use local images or registry
```

### 4. Deploy Application

```bash
# Using Helm
cd helm/voting-app
helm install voting-app . \
  --namespace voting-app \
  --create-namespace \
  --values values-dev.yaml \
  --set global.imageRegistry=""

# Or using kubectl
cd ../../aks
kubectl apply -k .
```

### 5. Test Application

```bash
# Port forward
kubectl port-forward service/vote 8080:80 -n voting-app
kubectl port-forward service/result 8081:4000 -n voting-app

# Access
curl http://localhost:8080
curl http://localhost:8081
```

### 6. Clean Up

```bash
# Delete application
helm uninstall voting-app -n voting-app
# or
kubectl delete namespace voting-app

# Stop cluster (minikube)
minikube stop
```

## Best Practices

1. **Use minikube for Windows/macOS** development
2. **Use k3s for Linux** (lightweight and fast)
3. **Use microk8s for Ubuntu/Debian** (snap-based)
4. **Enable all required add-ons** before deployment
5. **Use local images** to avoid pull issues
6. **Clean up regularly** to free resources
7. **Use Terraform** for consistent infrastructure

## Next Steps

After local cluster is set up:

1. **Deploy Infrastructure** using Terraform
2. **Deploy Application** using Helm or kubectl
3. **Test Locally** before deploying to Azure
4. **Migrate to Azure** when ready for production

See:
- `terraform/README.md` for Terraform setup
- `aks/HELM_DEPLOYMENT_GUIDE.md` for Helm deployment
- `terraform/LOCAL_CLUSTER_TRADEOFFS.md` for trade-offs

