# pal-e-platform

Portable K8s platform infrastructure managed by Terraform. Hosts [pal-e](https://github.com/ldraney/mcp-gateway-k8s) and all future projects on a self-hosted k3s cluster, with a clean path to any cloud provider.

## Tech Stack

| Layer | Tool | Language | Purpose |
|-------|------|----------|---------|
| IaC | OpenTofu (Terraform) | Go | Declarative infrastructure management |
| GitOps | ArgoCD | Go | Apps deploy themselves from git |
| Service mesh | TBD (Linkerd vs Istio spike) | Go/C++ | mTLS, observability, traffic management |
| Registry | Harbor | Go | In-cluster container image storage |
| Builds | TBD (Kaniko vs native spike) | Go | Build container images inside the cluster |
| Object storage | MinIO | Go | S3-compatible, in-cluster |
| Metrics | Prometheus + Grafana | Go | Collection, dashboards, alerting |
| Logs | Loki + Promtail | Go | Lightweight log aggregation |
| Traces | Grafana Tempo | Go | Distributed tracing |
| Profiles | Grafana Pyroscope | Go | Continuous profiling (CPU, memory) |
| Instrumentation | OpenTelemetry | Various | Vendor-neutral telemetry standard |
| TLS | cert-manager | Go | Automated certificate lifecycle |
| Ingress | Traefik | Go | K3s default, IngressRoute CRDs |
| Alerting | Alertmanager | Go | Alert routing and deduplication |

## Architecture Principles

1. **In-cluster by default.** Every infrastructure need is met by a self-hosted service. Cloud-managed services (ECR, S3, RDS) are opt-in when scale justifies cost.
2. **Namespaces as projects.** Each project gets its own namespace, its own Terraform state, its own blast radius. Platform services (registry, monitoring) live in a shared namespace.
3. **Terraform for infrastructure, ArgoCD for apps.** Terraform manages the platform layer. ArgoCD deploys application workloads from git. Clean separation.
4. **Portable across substrates.** Same Helm charts run on k3s or EKS. Environment differences live in .tfvars files, not in code.
5. **Observable from day one.** Metrics, logs, traces, and profiles are platform concerns, not afterthoughts.

## Terraform Layout

```
terraform/
├── modules/                    # Reusable building blocks (no state)
│   ├── ollama/
│   ├── mcp-server/
│   ├── postgres/
│   └── web-service/
│
├── platform/                   # Shared infra (own state)
│   ├── main.tf                 # Harbor, MinIO, monitoring, ArgoCD
│   ├── providers.tf
│   ├── variables.tf
│   └── k3s.tfvars
│
├── openclaw/                   # OpenClaw project (own state)
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── k3s.tfvars
│
└── <project>/                  # Future projects (own state each)
```

Each directory is its own `terraform apply` with its own state file. Modules are shared. Platform deploys first, projects depend on it.

## Dependency Graph

```
platform/  (Harbor, MinIO, ArgoCD, monitoring)
    ↑ images, storage, metrics, GitOps
    │
├── openclaw/   (gateway, Ollama, MCP servers)
├── blog/       (web server, Postgres)
├── pal-e-assets/ (MinIO-backed file storage)
└── ...         (future projects)
```

## Spikes (open questions)

- **Service mesh:** Linkerd vs Istio vs plain IngressRoute CRDs — what actually adds value for our scale?
- **Image builds:** Kaniko vs buildah vs native containerd — what's the K8s-native way?
- **Rust in the stack:** Which components benefit from Rust? Where does fighting the Go ecosystem hurt more than help?
