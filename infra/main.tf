data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "./modules/vpc"
  vpc_cidr = "10.0.0.0/16"
  environment = "dev"
  availability_zones = data.aws_availability_zones.available.names
}

