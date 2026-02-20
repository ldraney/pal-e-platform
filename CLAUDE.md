# pal-e-platform

Bootstrap repo: deploys Tailscale + observability + Forgejo + Woodpecker CI onto existing k3s.

## Tech Context

- **IaC**: OpenTofu (`tofu` not `terraform`). Helm charts deployed via the Terraform Helm provider.
- **Cluster**: k3s with Tailscale funnels for ingress and TLS. No cert-manager. No Traefik.
- **CI**: Woodpecker CI (deployed by this repo). No GitHub Actions — all CI is self-hosted.
- **State**: Local terraform state for now. Remote backend is a post-bootstrap concern.
- **Relationship**: This repo (bootstrap) provides the platform. [pal-e-services](https://github.com/ldraney/pal-e-services) consumes it for service onboarding, app deployments, and workload management.

## Agent Dispatch

- **Devy**: Writes all code. Follows SOP in `~/.claude/CLAUDE.md`. Creates issues, branches, PRs.
- **Mandy**: Routes comms. Does not write code in this repo.

## Issue Conventions

- **Features** link to a README roadmap item. Use the feature issue template.
- **Bugs** describe what broke. Use the bug issue template.
- All work references a parent epic or roadmap milestone.

## PR Conventions

- Include `tofu plan` output for any Terraform changes.
- Run `tofu fmt` and `tofu validate` before pushing.
- Note any discovered scope (work identified but deferred to a new issue).
- Check if README roadmap needs updating.
- PR goes through review-fix loop before presenting to user.
