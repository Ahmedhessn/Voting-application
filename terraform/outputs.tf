output "resource_group_name" {
  description = "Name of the resource group"
  value       = var.deploy_to_azure ? azurerm_resource_group.main[0].name : null
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = var.deploy_to_azure ? azurerm_kubernetes_cluster.main[0].name : null
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = var.deploy_to_azure ? azurerm_kubernetes_cluster.main[0].fqdn : null
}

output "kube_config" {
  description = "Kubernetes configuration (sensitive)"
  value       = var.deploy_to_azure ? azurerm_kubernetes_cluster.main[0].kube_config_raw : null
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = var.deploy_to_azure ? azurerm_kubernetes_cluster.main[0].kube_config[0].host : "Use local cluster"
}

output "ingress_nginx_status" {
  description = "Status of ingress-nginx helm release"
  value       = helm_release.ingress_nginx.status
}

output "acr_login_server" {
  description = "Azure Container Registry login server"
  value       = var.deploy_to_azure ? azurerm_container_registry.main[0].login_server : null
}

output "acr_name" {
  description = "Azure Container Registry name"
  value       = var.deploy_to_azure ? azurerm_container_registry.main[0].name : null
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = var.deploy_to_azure ? azurerm_virtual_network.main[0].id : null
}

output "postgresql_status" {
  description = "Status of PostgreSQL helm release"
  value       = var.deploy_postgresql_via_helm ? helm_release.postgresql[0].status : "Not deployed via Helm"
}

output "redis_status" {
  description = "Status of Redis helm release"
  value       = var.deploy_redis_via_helm ? helm_release.redis[0].status : "Not deployed via Helm"
}

