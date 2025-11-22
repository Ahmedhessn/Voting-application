# Terraform Infrastructure as Code

This directory contains Terraform configurations for provisioning the Voting Application infrastructure on Azure Kubernetes Service (AKS) or local Kubernetes clusters (minikube/k3s/microk8s).

## Features

- ✅ **Multi-environment support** (dev, staging, prod) using Terraform workspaces and variable files
- ✅ **Azure AKS cluster** with networking, security groups, and ingress controller
- ✅ **Local cluster support** (minikube/k3s/microk8s) for development
- ✅ **Azure Container Registry (ACR)** for container images
- ✅ **Network Security Groups (NSG)** with proper firewall rules
- ✅ **NGINX Ingress Controller** via Helm
- ✅ **PostgreSQL and Redis** via Bitnami Helm charts with persistence
- ✅ **Azure Monitor integration** (optional)
- ✅ **Azure Policy** support (optional)

## Prerequisites

1. **Terraform** >= 1.0 installed
   ```bash
   terraform version
   ```

2. **Azure CLI** installed and logged in (for Azure deployment)
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

3. **kubectl** installed
   ```bash
   kubectl version --client
   ```

4. **Helm 3** installed
   ```bash
   helm version
   ```

5. **Local Kubernetes cluster** (optional, for local development)
   - minikube, k3s, or microk8s

## Quick Start

### Azure Deployment

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Create/Select Workspace**
   ```bash
   # For development
   terraform workspace new dev
   terraform workspace select dev
   
   # For production
   terraform workspace new prod
   terraform workspace select prod
   ```

3. **Review and Update Variables**
   ```bash
   # Copy example file
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit terraform.tfvars with your values
   # Or use environment-specific files:
   # - dev.tfvars (for development)
   # - prod.tfvars (for production)
   ```

4. **Plan Deployment**
   ```bash
   terraform plan -var-file=dev.tfvars
   ```

5. **Apply Configuration**
   ```bash
   terraform apply -var-file=dev.tfvars
   ```

6. **Get Outputs**
   ```bash
   terraform output
   ```

### Local Cluster Deployment

1. **Set up Local Cluster**
   ```bash
   # For minikube
   minikube start
   
   # For k3s (Linux)
   curl -sfL https://get.k3s.io | sh -
   
   # For microk8s (Linux)
   snap install microk8s --classic
   microk8s enable dns storage ingress
   ```

2. **Configure Terraform**
   ```bash
   # Use dev.tfvars with deploy_to_azure = false
   terraform apply -var-file=dev.tfvars
   ```

## Configuration Files

### Variable Files

- **dev.tfvars** - Development environment configuration
- **prod.tfvars** - Production environment configuration
- **terraform.tfvars.example** - Example configuration file

### Main Files

- **main.tf** - Main Terraform configuration
- **variables.tf** - Variable definitions
- **outputs.tf** - Output values

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment` | Environment name (dev/staging/prod) | `dev` |
| `deploy_to_azure` | Deploy to Azure (true) or local (false) | `false` |
| `node_count` | Number of AKS nodes | `2` |
| `node_vm_size` | VM size for nodes | `Standard_B2s` |
| `deploy_postgresql_via_helm` | Use Helm for PostgreSQL | `true` |
| `deploy_redis_via_helm` | Use Helm for Redis | `true` |
| `postgres_password` | PostgreSQL password | `postgres` |

## Multi-Environment Setup

### Using Workspaces

```bash
# Create and switch to dev workspace
terraform workspace new dev
terraform workspace select dev
terraform apply -var-file=dev.tfvars

# Create and switch to prod workspace
terraform workspace new prod
terraform workspace select prod
terraform apply -var-file=prod.tfvars
```

### Using Variable Files

```bash
# Deploy to dev
terraform apply -var-file=dev.tfvars

# Deploy to prod
terraform apply -var-file=prod.tfvars
```

## Infrastructure Components

### Azure Resources (when `deploy_to_azure = true`)

1. **Resource Group** - Container for all resources
2. **Virtual Network** - Network isolation
3. **Subnet** - AKS subnet with NSG
4. **Network Security Group** - Firewall rules
5. **Azure Container Registry** - Container image storage
6. **AKS Cluster** - Kubernetes cluster
7. **Role Assignment** - AKS access to ACR

### Kubernetes Resources (all environments)

1. **NGINX Ingress Controller** - Via Helm
2. **PostgreSQL** - Via Bitnami Helm chart (optional)
3. **Redis** - Via Bitnami Helm chart (optional)

## Network Security

The NSG includes rules for:
- **HTTPS (443)** - Allow inbound
- **HTTP (80)** - Allow inbound
- **SSH (22)** - Allow from specified source IP

## PostgreSQL and Redis Deployment

By default, PostgreSQL and Redis are deployed via Bitnami Helm charts with:
- ✅ Persistence enabled (production)
- ✅ Resource limits
- ✅ Security contexts (non-root)
- ✅ Storage classes (Azure: managed-csi)

To use Kubernetes manifests instead:
```hcl
deploy_postgresql_via_helm = false
deploy_redis_via_helm = false
```

Then deploy using the manifests in `k8s/base/` or `aks/` directories.

## Outputs

After deployment, get important information:

```bash
terraform output
```

Key outputs:
- `aks_cluster_name` - AKS cluster name
- `acr_login_server` - ACR login server for pushing images
- `cluster_endpoint` - Kubernetes API endpoint
- `postgresql_status` - PostgreSQL deployment status
- `redis_status` - Redis deployment status

## Secrets Management

### Development

Passwords are set via variables (not recommended for production):
```hcl
postgres_password = "your-password"
```

### Production

For production, use Azure Key Vault:

1. **Create Key Vault**
   ```bash
   az keyvault create --name <vault-name> --resource-group <rg-name>
   ```

2. **Store Secrets**
   ```bash
   az keyvault secret set --vault-name <vault-name> --name postgres-password --value <password>
   ```

3. **Reference in Terraform**
   ```hcl
   data "azurerm_key_vault_secret" "postgres_password" {
     name         = "postgres-password"
     key_vault_id = azurerm_key_vault.main.id
   }
   
   postgres_password = data.azurerm_key_vault_secret.postgres_password.value
   ```

## Local Cluster Trade-offs

See [LOCAL_CLUSTER_TRADEOFFS.md](./LOCAL_CLUSTER_TRADEOFFS.md) for detailed comparison.

### Quick Summary

| Feature | Azure AKS | Local (minikube/k3s/microk8s) |
|---------|-----------|-------------------------------|
| Cost | Pay per use | Free |
| Scalability | High | Limited |
| Production Ready | Yes | No |
| Networking | Advanced | Basic |
| Storage | Managed | Local |
| Monitoring | Azure Monitor | Manual setup |

## Troubleshooting

### Terraform Errors

```bash
# Refresh state
terraform refresh

# Validate configuration
terraform validate

# Show current state
terraform show
```

### AKS Connection Issues

```bash
# Get credentials
az aks get-credentials --resource-group <rg-name> --name <cluster-name>

# Verify connection
kubectl get nodes
```

### Helm Release Issues

```bash
# List releases
helm list -A

# Check release status
helm status <release-name> -n <namespace>

# Uninstall if needed
helm uninstall <release-name> -n <namespace>
```

## Cleanup

### Destroy Infrastructure

```bash
# Destroy all resources
terraform destroy -var-file=dev.tfvars
```

**Warning:** This will delete all resources including persistent data!

### Selective Cleanup

```bash
# Remove specific resource
terraform destroy -target=azurerm_kubernetes_cluster.main -var-file=dev.tfvars
```

## Best Practices

1. **Use Workspaces** - Separate state for each environment
2. **Version Control** - Commit `.tfvars` files (without secrets)
3. **Backend Configuration** - Use remote state (Azure Storage)
4. **Secrets Management** - Use Azure Key Vault for production
5. **Resource Tagging** - All resources are tagged for cost tracking
6. **Review Plans** - Always review `terraform plan` before applying

## Next Steps

After infrastructure is provisioned:

1. **Build and Push Images** to ACR
2. **Deploy Application** using Helm or kubectl
   - See `aks/HELM_DEPLOYMENT_GUIDE.md` for Helm
   - See `aks/DEPLOYMENT_GUIDE.md` for kubectl

## Support

For issues:
1. Check Terraform logs
2. Verify Azure permissions
3. Review variable values
4. Check Kubernetes cluster status
