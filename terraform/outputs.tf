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

