output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "auth_map" {
  description = "The Kubernetes Cluster auth map"
  value       = module.eks.aws_auth_configmap_yaml
}

output "iam_role" {
  description = "ARN of the IAM Role created"
  value       = module.eks.cluster_iam_role_arn
}
