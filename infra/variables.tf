variable "project_name" {
  type        = string
  description = "Project name used in resource names and tags."
  default     = "payrail"
}

variable "environment" {
  type        = string
  description = "Environment name used in resource names and tags."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS-compatible region. LocalStack defaults to us-east-1."
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  type        = string
  description = "LocalStack edge endpoint used by the AWS provider."
  default     = "http://localhost:4566"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the PayRail VPC."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zone_count" {
  type        = number
  description = "Number of availability zones to model locally."
  default     = 2

  validation {
    condition     = var.availability_zone_count > 0 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be between 1 and 3."
  }
}
