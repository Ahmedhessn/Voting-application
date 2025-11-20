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
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  role_based_access_control_enabled = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
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
    value = "LoadBalancer"
  }

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }
}

