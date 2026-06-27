# PayRail

PayRail is a local-first platform engineering portfolio project built around a small payment/ledger workflow. The payment domain is intentionally thin; the real artifact is the infrastructure, observability, policy enforcement, failure testing, runbooks, and postmortems around it.

The repository is now the canonical single repo for the project. Splitting docs and infrastructure into separate repos would add coordination overhead without proving anything useful for this kind of portfolio system.

## Local-First Direction

- Terraform targets LocalStack by default through `infra/provider.tf`.
- Kubernetes workloads should run on Kind for day-to-day development and incident drills.
- AWS remains an opt-in target for someone who wants to spend real money on a final smoke test.
- Real AWS users can replace the LocalStack provider with `infra/provider.aws.tf.example` and add the S3 backend example from `infra/backend.aws.tf.example`.

## Current Contents

- `docs/PRD.md` defines the project scope, service boundaries, SLO, incident set, and definition of done.
- `docs/architecture.md` explains the architecture and key technology choices.
- `infra/` contains the Terraform entry point and reusable modules.
- `infra/modules/vpc` models the VPC, public/private/database subnet layout, NAT path, and network ACLs.
- `infra/modules/eks` and `infra/modules/irsa` are retained as AWS-compatible building blocks, but local workload behavior should be validated on Kind.

## Local Infra Loop

Start LocalStack, then run Terraform from `infra`:

```bash
cd infra
terraform init
terraform fmt -recursive
terraform plan
```

The default provider points to `http://localhost:4566`, so these commands should not hit real AWS.

## Project Goal

PayRail v1 is done when the platform can be demonstrated locally with a working `payment-api` to `ledger-api` flow, GitOps-managed Kubernetes manifests, OpenTelemetry traces and metrics, one clear SLO, Kyverno policy enforcement, and four documented incidents with runbooks, postmortems, and remediation evidence.
