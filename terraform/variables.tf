variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID for the operator"
  type        = string
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret for the operator"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "tailscale_domain" {
  description = "Tailscale tailnet domain for funnel URLs"
  type        = string
  default     = "tail5b443a.ts.net"
}

variable "forgejo_admin_username" {
  description = "Forgejo admin username (cannot be 'admin')"
  type        = string
  default     = "forgejo_admin"
}

variable "forgejo_admin_password" {
  description = "Forgejo admin password"
  type        = string
  sensitive   = true
}

variable "forgejo_admin_email" {
  description = "Forgejo admin email"
  type        = string
  default     = "admin@forgejo.local"
}
