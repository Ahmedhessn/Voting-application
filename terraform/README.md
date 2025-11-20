# Terraform Infrastructure as Code

This directory contains Terraform configuration for provisioning the Kubernetes infrastructure for the Voting Application.

## Features

- **Multi-environment support**: Dev, Staging, and Prod environments
- **Flexible deployment**: Supports both Azure AKS and local clusters (minikube/k3s/microk8s)
- **Auto-scaling**: Configurable node pool auto-scaling for AKS
- **Ingress Controller**: Automatically deploys NGINX Ingress Controller

## Prerequisites

1. **Terraform** >= 1.0 installed
2. **Azure CLI** (if deploying to Azure)
3. **Kubectl** configured for your target cluster
4. **Helm** 3.x installed

## Quick Start

### For Local Development (minikube/k3s/microk8s)

1. Initialize Terraform:
```bash
terraform init
```

2. Review and customize variables:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set deploy_to_azure = false
```

3. Plan the deployment:
```bash
terraform plan -var-file=dev.tfvars
```

4. Apply the configuration:
```bash
terraform apply -var-file=dev.tfvars
```

### For Azure AKS

1. Login to Azure:
```bash
az login
az account set --subscription <your-subscription-id>
```

2. Initialize Terraform:
```bash
terraform init
```

3. Configure backend (optional but recommended):
Edit `main.tf` backend configuration or use environment variables.

4. Plan the deployment:
```bash
terraform plan -var-file=prod.tfvars
```

5. Apply the configuration:
```bash
terraform apply -var-file=prod.tfvars
```

## Configuration

### Variables

Key variables you can customize:

- `project_name`: Name of the project (default: "voting-app")
- `environment`: Environment name - dev, staging, or prod (default: "dev")
- `deploy_to_azure`: Whether to deploy to Azure AKS (default: false)
- `node_count`: Number of nodes in the default node pool
- `node_vm_size`: VM size for AKS nodes (default: "Standard_B2s")
- `enable_auto_scaling`: Enable auto-scaling (default: true)
- `min_node_count`: Minimum nodes when auto-scaling (default: 1)
- `max_node_count`: Maximum nodes when auto-scaling (default: 5)

### Environment-Specific Files

- `dev.tfvars`: Development environment configuration
- `prod.tfvars`: Production environment configuration

## Outputs

After applying, Terraform will output:

- Resource group name (Azure only)
- AKS cluster name (Azure only)
- Cluster endpoint
- Kubernetes configuration (sensitive)

## Local Cluster Setup

### Minikube

```bash
minikube start
kubectl config use-context minikube
terraform apply -var-file=dev.tfvars
```

### k3s

```bash
# k3s is usually already configured
terraform apply -var-file=dev.tfvars
```

### MicroK8s

```bash
microk8s kubectl config view --raw > ~/.kube/config
terraform apply -var-file=dev.tfvars
```

## Security Notes

- **Secrets**: Never commit `terraform.tfvars` files with sensitive data
- **Backend**: Configure remote backend for state management in production
- **RBAC**: AKS clusters are created with RBAC enabled
- **Network**: Uses kubenet networking plugin (can be changed to Azure CNI)

## Trade-offs: Local vs Azure

### Local Cluster (minikube/k3s/microk8s)

**Pros:**
- No cloud costs
- Fast iteration
- Good for development and testing
- No internet dependency

**Cons:**
- Limited scalability
- No high availability
- Manual backup/restore
- Limited to single machine resources

### Azure AKS

**Pros:**
- Production-grade infrastructure
- High availability and auto-scaling
- Managed Kubernetes service
- Integrated with Azure services
- Built-in monitoring and logging

**Cons:**
- Cloud costs
- Requires Azure subscription
- More complex setup
- Internet dependency

## Next Steps

After infrastructure is provisioned:

1. Deploy the application using Helm:
```bash
helm install voting-app ./helm/voting-app -f ./helm/voting-app/values-dev.yaml
```

2. Or use Kubernetes manifests:
```bash
kubectl apply -k k8s/overlays/dev
```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy -var-file=dev.tfvars
```

**Warning**: This will delete all resources created by Terraform!

