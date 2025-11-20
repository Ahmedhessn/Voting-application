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

