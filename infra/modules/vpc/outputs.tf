output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of private subnets (EKS nodes)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (NAT gateway, ALB if added later)"
  value       = aws_subnet.public[*].id
}

output "database_subnet_ids" {
  description = "IDs of subnets dedicated to RDS"
  value       = aws_subnet.database[*].id
}