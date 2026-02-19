# pal-e-platform

Bootstrap repo that deploys the minimum viable self-hosting stack onto an existing k3s cluster. Once Forgejo is running with observability, all future infrastructure work moves to self-hosted repos. GitHub is the disaster recovery entry point.

**Definition of done:** `tofu apply` produces a working Forgejo instance with CI and observability.

## Bootstrap Dependency Chain

```
k3s (exists)
  → cert-manager + Traefik (TLS + ingress)
    → Prometheus + Grafana + Loki (observability)
      → Forgejo (git hosting + container registry)
        → Woodpecker CI (build pipelines)
```

## Roadmap

- [ ] **TF foundation** — providers, state, cert-manager, Traefik config
- [ ] **Observability** — Prometheus, Grafana, Loki via Helm
- [ ] **Forgejo** — Forgejo deployment with Traefik ingress, built-in container registry
- [ ] **Woodpecker CI** — Woodpecker server + agents, Forgejo OAuth integration

Each milestone is its own GitHub issue, implemented as a separate PR.

## Tech Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| IaC | OpenTofu | Declarative infrastructure management |
| Cluster | k3s | Lightweight Kubernetes (pre-existing) |
| TLS | cert-manager | Automated certificate lifecycle |
| Ingress | Traefik | k3s default, IngressRoute CRDs |
| Metrics | Prometheus + Grafana | Collection and dashboards |
| Logs | Loki | Lightweight log aggregation |
| Git hosting | Forgejo | Self-hosted git + built-in OCI registry |
| CI | Woodpecker CI | Container-native CI, Forgejo-integrated |

## What Moves to Forgejo

These are explicitly **not in scope** for this repo. Once Forgejo is running, a new repo (hosted on Forgejo) handles:

- Harbor (if needed — Forgejo has a built-in container registry)
- MinIO (S3-compatible object storage)
- ArgoCD (GitOps app deployments)
- Application deployments (mcp-gateway-k8s import, pal-e-assets, etc.)
- Production workload management

## Terraform Layout

```
terraform/
├── main.tf           # Bootstrap resources
├── providers.tf      # k3s, Helm, kubectl providers
├── variables.tf
├── outputs.tf
├── k3s.tfvars
└── versions.tf
```

Single root module. No sub-modules until complexity justifies them.

## State Management

Local state (`terraform.tfstate`) for now. Remote backend (S3-compatible on MinIO or similar) is a post-bootstrap concern — you need the platform running before you can host state on it.

## Architecture Principles

1. **Bootstrap-first.** Get the self-hosting stack running before optimizing anything. Perfect is the enemy of deployed.
2. **Repos have an end.** This repo's job is done when Forgejo + CI + observability are running. Future work lives in future repos.
3. **In-cluster by default.** Every infrastructure need is met by a self-hosted service. Cloud-managed services are opt-in when scale justifies cost.
4. **Portable across substrates.** Same Helm charts run on k3s or EKS. Environment differences live in .tfvars files, not in code.
5. **Observable from day one.** Metrics and logs are platform concerns, not afterthoughts.
