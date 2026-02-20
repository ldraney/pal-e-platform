output "tailscale_operator_status" {
  description = "Tailscale operator Helm release status"
  value       = helm_release.tailscale_operator.status
}

output "grafana_url" {
  description = "Grafana dashboard URL (Tailscale funnel)"
  value       = "https://grafana.${var.tailscale_domain}"
}

output "prometheus_internal_url" {
  description = "Prometheus internal cluster URL"
  value       = "http://kube-prometheus-stack-prometheus.monitoring:9090"
}

output "loki_internal_url" {
  description = "Loki internal cluster URL"
  value       = "http://loki-stack.monitoring:3100"
}

output "forgejo_url" {
  description = "Forgejo URL (Tailscale funnel)"
  value       = "https://forgejo.${var.tailscale_domain}"
}

output "woodpecker_url" {
  description = "Woodpecker CI URL (Tailscale funnel)"
  value       = "https://woodpecker.${var.tailscale_domain}"
}

output "harbor_url" {
  description = "Harbor container registry URL (Tailscale funnel)"
  value       = "https://harbor.${var.tailscale_domain}"
}
