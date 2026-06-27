bucket         = "replace-with-payrail-terraform-state-bucket"
key            = "infra/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "replace-with-payrail-terraform-locks"
