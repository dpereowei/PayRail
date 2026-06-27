output "vpc_id" {
  description = "ID of the PayRail VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for Kubernetes worker nodes or internal workloads."
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs for RDS-style resources."
  value       = module.vpc.database_subnet_ids
}
