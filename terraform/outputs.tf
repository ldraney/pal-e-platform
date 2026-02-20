output "tailscale_operator_status" {
  description = "Tailscale operator Helm release status"
  value       = helm_release.tailscale_operator.status
}
