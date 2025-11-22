terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    # Configure backend in terraform.tfvars or via environment variables
    # resource_group_name  = "tfstate"
    # storage_account_name = "tfstate"
    # container_name       = "tfstate"
    # key                  = "voting-app.terraform.tfstate"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
}

# Data source for current Azure subscription
data "azurerm_subscription" "current" {}

# Resource group
resource "azurerm_resource_group" "main" {
  count    = var.deploy_to_azure ? 1 : 0
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.azure_location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  count               = var.deploy_to_azure ? 1 : 0
  name                = "${var.project_name}${var.environment}acr"
  resource_group_name = azurerm_resource_group.main[0].name
  location            = azurerm_resource_group.main[0].location
  sku                 = var.environment == "prod" ? "Premium" : "Basic"
  admin_enabled       = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Virtual Network for AKS
resource "azurerm_virtual_network" "main" {
  count               = var.deploy_to_azure ? 1 : 0
  name                = "${var.project_name}-${var.environment}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main[0].location
  resource_group_name = azurerm_resource_group.main[0].name

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy     = "Terraform"
  }
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  count                = var.deploy_to_azure ? 1 : 0
  name                 = "${var.project_name}-${var.environment}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main[0].name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.aks_subnet_address_prefix]
}

# Network Security Group for AKS
resource "azurerm_network_security_group" "aks" {
  count               = var.deploy_to_azure ? 1 : 0
  name                = "${var.project_name}-${var.environment}-aks-nsg"
  location            = azurerm_resource_group.main[0].location
  resource_group_name = azurerm_resource_group.main[0].name

  # Allow inbound HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow inbound HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range    = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow inbound SSH (for node access)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range    = "22"
    source_address_prefix      = var.allowed_ssh_source_ip
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "aks" {
  count                     = var.deploy_to_azure ? 1 : 0
  subnet_id                 = azurerm_subnet.aks[0].id
  network_security_group_id = azurerm_network_security_group.aks[0].id
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  count               = var.deploy_to_azure ? 1 : 0
  name                = "${var.project_name}-${var.environment}-aks"
  location            = azurerm_resource_group.main[0].location
  resource_group_name = azurerm_resource_group.main[0].name
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.enable_auto_scaling ? var.min_node_count : null
    max_count           = var.enable_auto_scaling ? var.max_node_count : null
    os_disk_size_gb     = var.os_disk_size_gb
    type                = "VirtualMachineScaleSets"
    vnet_subnet_id      = azurerm_subnet.aks[0].id
  }

  identity {
    type = "SystemAssigned"
  }

  # Attach ACR
  role_based_access_control_enabled = true

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  # Enable Azure Policy
  azure_policy_enabled = var.enable_azure_policy

  # Enable OMS (Azure Monitor)
  oms_agent {
    enabled                    = var.enable_azure_monitor
    log_analytics_workspace_id = var.enable_azure_monitor && var.log_analytics_workspace_id != "" ? var.log_analytics_workspace_id : null
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  count                = var.deploy_to_azure ? 1 : 0
  principal_id         = azurerm_kubernetes_cluster.main[0].identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.main[0].id
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = var.deploy_to_azure ? azurerm_kubernetes_cluster.main[0].kube_config[0].host : var.local_kubeconfig_path != "" ? null : "https://kubernetes.default.svc"
  client_certificate     = var.deploy_to_azure ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].client_certificate) : null
  client_key             = var.deploy_to_azure ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].client_key) : null
  cluster_ca_certificate  = var.deploy_to_azure ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].cluster_ca_certificate) : null
  config_path            = var.local_kubeconfig_path != "" ? var.local_kubeconfig_path : null
  config_context         = var.local_kubeconfig_context != "" ? var.local_kubeconfig_context : null
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = var.deploy_to_azure ? azurerm_kubernetes_cluster.main[0].kube_config[0].host : var.local_kubeconfig_path != "" ? null : "https://kubernetes.default.svc"
    client_certificate     = var.deploy_to_azure ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].client_certificate) : null
    client_key             = var.deploy_to_azure ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].client_key) : null
    cluster_ca_certificate  = var.deploy_to_azure ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].cluster_ca_certificate) : null
    config_path            = var.local_kubeconfig_path != "" ? var.local_kubeconfig_path : null
    config_context         = var.local_kubeconfig_context != "" ? var.local_kubeconfig_context : null
  }
}

# Ingress NGINX Controller
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.0"
  namespace  = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = var.deploy_to_azure ? "LoadBalancer" : "NodePort"
  }

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.podSecurityPolicy.enabled"
    value = "false"
  }

  depends_on = [
    azurerm_kubernetes_cluster.main
  ]
}

# PostgreSQL via Bitnami Helm Chart
resource "helm_release" "postgresql" {
  count      = var.deploy_postgresql_via_helm ? 1 : 0
  name        = "postgresql"
  repository  = "https://charts.bitnami.com/bitnami"
  chart       = "postgresql"
  version     = "12.1.0"
  namespace   = "voting-app"
  create_namespace = true

  set {
    name  = "auth.database"
    value = "postgres"
  }

  set {
    name  = "auth.username"
    value = "postgres"
  }

  set {
    name  = "auth.password"
    value = var.postgres_password
  }

  set {
    name  = "primary.persistence.enabled"
    value = "true"
  }

  set {
    name  = "primary.persistence.size"
    value = var.environment == "prod" ? "50Gi" : "10Gi"
  }

  set {
    name  = "primary.persistence.storageClass"
    value = var.deploy_to_azure ? "managed-csi" : ""
  }

  set {
    name  = "primary.resources.requests.memory"
    value = var.environment == "prod" ? "512Mi" : "256Mi"
  }

  set {
    name  = "primary.resources.requests.cpu"
    value = var.environment == "prod" ? "500m" : "250m"
  }

  set {
    name  = "primary.resources.limits.memory"
    value = var.environment == "prod" ? "2Gi" : "512Mi"
  }

  set {
    name  = "primary.resources.limits.cpu"
    value = var.environment == "prod" ? "2000m" : "1000m"
  }

  set {
    name  = "primary.podSecurityContext.enabled"
    value = "true"
  }

  set {
    name  = "primary.podSecurityContext.fsGroup"
    value = "999"
  }

  set {
    name  = "primary.containerSecurityContext.enabled"
    value = "true"
  }

  set {
    name  = "primary.containerSecurityContext.runAsUser"
    value = "999"
  }

  set {
    name  = "primary.containerSecurityContext.runAsNonRoot"
    value = "true"
  }

  depends_on = [
    helm_release.ingress_nginx
  ]
}

# Redis via Bitnami Helm Chart
resource "helm_release" "redis" {
  count      = var.deploy_redis_via_helm ? 1 : 0
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = "17.15.0"
  namespace  = "voting-app"
  create_namespace = true

  set {
    name  = "auth.enabled"
    value = "false"
  }

  set {
    name  = "master.persistence.enabled"
    value = var.environment == "prod" ? "true" : "false"
  }

  set {
    name  = "master.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "master.persistence.storageClass"
    value = var.deploy_to_azure ? "managed-csi" : ""
  }

  set {
    name  = "master.resources.requests.memory"
    value = var.environment == "prod" ? "256Mi" : "128Mi"
  }

  set {
    name  = "master.resources.requests.cpu"
    value = var.environment == "prod" ? "200m" : "100m"
  }

  set {
    name  = "master.resources.limits.memory"
    value = var.environment == "prod" ? "512Mi" : "256Mi"
  }

  set {
    name  = "master.resources.limits.cpu"
    value = var.environment == "prod" ? "1000m" : "500m"
  }

  set {
    name  = "master.podSecurityContext.enabled"
    value = "true"
  }

  set {
    name  = "master.podSecurityContext.fsGroup"
    value = "999"
  }

  set {
    name  = "master.containerSecurityContext.enabled"
    value = "true"
  }

  set {
    name  = "master.containerSecurityContext.runAsUser"
    value = "999"
  }

  set {
    name  = "master.containerSecurityContext.runAsNonRoot"
    value = "true"
  }

  depends_on = [
    helm_release.ingress_nginx
  ]
}

