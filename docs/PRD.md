# PayRail Product Requirements Document

**Status:** Draft v1.0 <br>
**Owner:** Pereowei Daniel <br>
**Purpose:** Portfolio project demonstrating platform engineering, DevSecOps, and SRE incident-response capability through a simulated payment-processing microservice stack using LocalStack, Kind, and AWS-compatible Terraform.

---

## 1. Executive Summary

PayRail is a minimal but production-shaped payment/settlement system built specifically to generate, detect, diagnose, and document realistic distributed-systems incidents. The infrastructure is the means. The incidents and their runbooks, traces, burn-rate calculations, and postmortems are the product.

The default implementation target is local-first: Terraform talks to LocalStack for AWS-shaped infrastructure, while Kubernetes workloads run on Kind. Real AWS remains an optional smoke-test target, not the day-to-day development environment.

**Guiding principle for every scope decision below:** if a feature does not directly produce an interview-worthy artifact (a postmortem, a runbook, a burn-rate chart, a policy-prevented incident), it does not get built.

---

## 2. Goals & Success Criteria

The project is "done" when the following exist and can be demonstrated:

- A working `payment-api` → `ledger-api` settlement flow, deployed via GitOps (ArgoCD) to Kind
- AWS-compatible infrastructure applied against LocalStack by default
- Three enforced Kyverno policies, with evidence that at least one of them prevents a real incident
- One precisely defined SLO with a calculated error budget and multi-window, multi-burn-rate alerting
- **Four** fully documented incidents, each with: alert, investigation (metrics + trace), runbook, postmortem (including burn-rate consumption), and remediation
- A README/architecture doc that explains every major tooling decision and *why* the alternative was rejected (this is itself an artifact see Section 9)

### Non-Goals (explicitly out of scope)

- Backstage or any developer portal
- More than 2 application services
- A full self-hosted LGTM stack
- ALB / Load Balancer Controller chaos scenarios
- Spot-interruption / node-failure chaos scenarios
- More than 3 governance policies
- More than 4 documented incidents

If a future iteration wants any of the above, it's a "v2" decision, made only after all four incidents in v1 are fully written up.

---

## 3. Architecture Overview

### 3.1 Services (2 total)

**`payment-api`**
- `POST /payments` accepts a payment request, creates a transaction in `PENDING` state
- Emits an async settlement callback to `ledger-api` (via a lightweight internal job/script *not* a third service)
- Exposes Prometheus metrics + OpenTelemetry traces

**`ledger-api`**
- `POST /settlement-webhook` receives the settlement callback
  - Verifies a signature (HMAC) on the payload
  - Validates an idempotency key (rejects/handles duplicate deliveries)
  - Updates the ledger record to `SETTLED`
- Backed by Postgres locally, with an RDS-shaped infrastructure path for AWS-compatible validation
- Exposes Prometheus metrics + OpenTelemetry traces

### 3.2 Flow

```
payment initiated (payment-api, PENDING)
        ↓
settlement callback (POST /settlement-webhook)
        ↓
signature + idempotency check
        ↓
ledger updated (ledger-api, SETTLED)
```

This flow is the basis for incident #2 (Section 6).

### 3.3 Environment Strategy

| Stage | Environment | Rationale |
|---|---|---|
| Application development | Kind | Fast iteration, no cloud cost |
| AWS-shaped infrastructure validation | LocalStack | Exercise Terraform against AWS-compatible APIs without AWS spend |
| Kubernetes platform validation | Kind | Validate ArgoCD, Kyverno, rollouts, services, and incident drills locally |
| Optional final smoke | Real AWS | Explicit opt-in only if the cost is acceptable |

---

## 4. Infrastructure

- **IaC:** Terraform VPC, IAM/IRSA-shaped roles, RDS-shaped database resources, security groups, and Secrets Manager entries against LocalStack by default
- **GitOps:** ArgoCD `git push` → sync → deploy into Kind is the success criterion for Phase 1
- **Database:** LocalStack-modeled RDS/Postgres shape for infrastructure; local Postgres container can back the running `ledger-api` when actual database behavior is needed

### Cost Management (mandatory, not optional)

- No real AWS resources should be created by default; LocalStack is the normal infrastructure target
- Any real AWS run must be explicit, time-boxed, and followed by `terraform destroy`
- Maintain a running cost log in the repo (`docs/cost-log.md`) if any real AWS smoke tests are performed this doubles as evidence of cost-awareness, a real platform-engineering competency

---

## 5. Observability

- **Instrumentation:** OpenTelemetry SDK in both services (metrics + traces)
- **Pipeline:** OpenTelemetry Collector deployed in-cluster, forwarding to Grafana Cloud (free tier)
- **Backend:** Grafana Cloud Prometheus-compatible metrics, Tempo for traces, dashboards
- No self-hosted Loki/Tempo/Mimir/Prometheus stack

### 5.1 SLO Definition (exactly one)

> **99.9% of `POST /payments` requests complete successfully**, where "successful" = HTTP status `< 500` AND latency `< 500ms`.

### 5.2 Error Budget

- Monthly request volume assumption: documented explicitly (e.g., 1,000,000 requests/month)
- Allowed failures at 99.9%: 1,000 requests/month
- Every incident postmortem must state: requests affected, % of monthly error budget consumed, and time-to-consume

### 5.3 Alerting

- **Fast-burn alert:** short window (e.g., 1h), high burn-rate threshold (e.g., 14.4x) catches severe, fast incidents
- **Slow-burn alert:** longer window (e.g., 6h), lower threshold (e.g., 6x) catches creeping degradation
- Both must be implemented and both must fire at least once across the four incidents if a scenario doesn't naturally trigger one of them, adjust the scenario, don't skip the alert type

---

## 6. Governance Kyverno Policies (exactly 3)

1. **No privileged containers** `securityContext.privileged: false` enforced
2. **Mandatory resource requests and limits** every container must define CPU/memory requests and limits
3. **No `:latest` image tag** all deployments must reference an immutable tag/digest

Policy #2 is load-bearing for Incident #1 (Section 7) it must be demonstrably *absent* for the "before" run and *enforced* for the "after" run.

Each policy gets a short README section explaining: what it prevents, why Kyverno was chosen over OPA/Gatekeeper for this policy specifically, and what a Rego-based equivalent would look like (this is the "senior judgment" artifact see Section 9).

---

## 7. Incident Scenarios (exactly 4)

For each incident, the following artifacts are **mandatory deliverables**:

| Artifact | Description |
|---|---|
| Alert | Screenshot/export of the fired alert (fast-burn or slow-burn) |
| Investigation | Metrics dashboard + trace showing root cause |
| Runbook | Step-by-step response procedure, written *before* the incident is triggered |
| Postmortem | Timeline, impact, error-budget consumption %, root cause, contributing factors |
| Remediation | Concrete fix applied (code, policy, or config change) + verification it works |

### Incident 1 Resource Exhaustion (run twice)

- **Before:** Deploy `ledger-api` without resource limits → induce memory pressure → observe OOM/cascading node pressure → degraded payment processing → full postmortem
- **After:** Apply Kyverno policy #2 → re-run the same load pattern → demonstrate the deployment is rejected or the blast radius is contained → short addendum postmortem showing prevention
- **Narrative payoff:** incident → root cause → policy → prevention, in one closed loop

### Incident 2 Settlement Webhook Dependency Outage

- `ledger-api` becomes unavailable (pod deleted / scaled to zero) while `payment-api` continues accepting `POST /payments`
- Demonstrates: queued/retried settlement callbacks, idempotency handling on recovery, SLO burn during the outage window
- **Narrative payoff:** domain-specific async-callback failure, directly tied to real settlement-flow operations

### Incident 3 Database Connectivity Misconfiguration

- Modify the security group-shaped rule or local network configuration so `ledger-api` cannot reach the database
- Demonstrates: connection-pool exhaustion, error-rate spike, trace showing failure at the DB call, time-to-detect via alert
- **Narrative payoff:** realistic "routine hardening pass broke prod" story common to Kubernetes and AWS-backed systems

### Incident 4 Bad Deployment / ArgoCD Rollback

- Ship a deployment with a deliberate regression (e.g., broken settlement signature validation)
- Demonstrates: alert fires on error-rate increase, ArgoCD rollback (manual or automated), recovery confirmed via metrics
- **Narrative payoff:** GitOps as a recovery mechanism, not just a deploy mechanism

---

## 8. Sequencing Note

Incident 1's "before" run **must happen before or during Phase 4** (policy rollout), since Kyverno policy #2 must not yet be enforced for that run. Plan this explicitly do not let policy rollout get ahead of the "before" incident, or it becomes unreproducible without temporarily disabling the policy.

---

## 9. Documentation Deliverables (beyond the per-incident artifacts)

- `README.md` architecture overview, diagram, "why this stack" decision log (Kyverno vs OPA/Gatekeeper, Grafana Cloud vs self-hosted, LocalStack vs real AWS, Kind vs EKS, RDS/local Postgres tradeoff)
- `docs/cost-log.md` running infrastructure cost tracking
- `docs/slo.md` SLO definition, error budget math, burn-rate alert configuration
- 4x `docs/incidents/INC-00X-*.md` full artifact set per Section 7

---

## 10. Phased Roadmap

| Phase | Scope | Notes |
|---|---|---|
| 1 | Terraform: LocalStack VPC/IAM/RDS-shaped resources, Kind cluster, ArgoCD bootstrap | Success = `git push` → ArgoCD sync → app deployed locally. Budget 1.5–2 weeks; local GitOps and policy wiring are the likely time sinks. |
| 2 | `payment-api` + `ledger-api`, settlement-webhook flow, Postgres integration | Simple, no extra business logic |
| 3 | OpenTelemetry → Grafana Cloud (metrics + traces), define the one SLO, configure fast/slow burn-rate alerts | |
| 4 | Kyverno: 3 policies. Run Incident 1 "before" prior to/during this phase | |
| 5 | Incidents 2, 3, 4 + Incident 1 "after" full artifact set for all four | This is where the majority of effort goes |
| 6 | Documentation pass: README decision log, cost log, SLO doc, final polish on all 4 incident writeups | |

**Timeline:** 6 weeks is the floor, 8–10 weeks is a realistic ceiling for part-time work. Slippage in Phase 1 is expected and acceptable. Slippage that compresses Phase 5 is not.

---

## 11. Open Questions / Risks

- Confirm Grafana Cloud free-tier limits (10k series / 50GB logs+traces) are sufficient for the chaos-testing volume monitor usage from Phase 3 onward
- Decide whether any final real-AWS smoke test is worth the cost; if not, document LocalStack/Kind evidence clearly
- Decide the exact mechanism for triggering the settlement callback in Incident 2 (internal job/cron vs. manual trigger script) must be lightweight, not a third service
- Decide monthly request-volume assumption for error-budget math before Phase 3 (needed for all postmortem calculations)

---

## 12. Definition of Done

PayRail v1 is complete when: the infrastructure workflow runs locally, the application deploys via GitOps, all 3 Kyverno policies are enforced, the SLO and both burn-rate alerts are live and have fired at least once each across the incident set, and all four incidents have a complete artifact set (alert, investigation, runbook, postmortem with burn-rate math, remediation) committed to the repo.
