variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "voting-app"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "deploy_to_azure" {
  description = "Whether to deploy to Azure AKS (true) or use local cluster (false)"
  type        = bool
  default     = false
}

variable "azure_location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pool"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 5
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for nodes"
  type        = number
  default     = 30
}

variable "local_kubeconfig_path" {
  description = "Path to kubeconfig file for local cluster (minikube/k3s/microk8s). Leave empty to use default."
  type        = string
  default     = ""
}

variable "local_kubeconfig_context" {
  description = "Kubernetes context to use for local cluster"
  type        = string
  default     = ""
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

variable "allowed_ssh_source_ip" {
  description = "Source IP address allowed for SSH access (use * for all)"
  type        = string
  default     = "*"
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy for Kubernetes"
  type        = bool
  default     = false
}

variable "enable_azure_monitor" {
  description = "Enable Azure Monitor (OMS) for AKS"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for Azure Monitor (optional)"
  type        = string
  default     = ""
}

variable "deploy_postgresql_via_helm" {
  description = "Deploy PostgreSQL via Bitnami Helm chart (true) or use manifests (false)"
  type        = bool
  default     = true
}

variable "deploy_redis_via_helm" {
  description = "Deploy Redis via Bitnami Helm chart (true) or use manifests (false)"
  type        = bool
  default     = true
}

variable "postgres_password" {
  description = "PostgreSQL password (use Azure Key Vault in production)"
  type        = string
  sensitive   = true
  default     = "postgres"
}

