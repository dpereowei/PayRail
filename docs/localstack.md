# LocalStack Workflow

PayRail defaults to LocalStack for Terraform so routine infrastructure work does not create AWS spend.

## Prerequisites

- Docker
- Terraform
- LocalStack running on `http://localhost:4566`

## Run Terraform Locally

```bash
cd infra
terraform init
terraform plan
```

The default AWS provider in `provider.tf` uses dummy credentials and LocalStack endpoints. It should not contact real AWS.

## Switching To Real AWS

Real AWS is opt-in:

1. Replace the LocalStack provider in `provider.tf` with the provider from `provider.aws.tf.example`.
2. If remote state is needed, copy `backend.aws.tf.example` to `backend.tf`.
3. Fill in `backend.aws.example.hcl` with a real state bucket and lock table.
4. Reinitialize Terraform with the backend config.

```bash
terraform init -backend-config=backend.aws.example.hcl
```

Use real AWS only for deliberate smoke tests or final demonstration captures. The normal development loop should stay local.
