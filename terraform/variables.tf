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

variable "woodpecker_forgejo_client" {
  description = "Forgejo OAuth client ID for Woodpecker CI"
  type        = string
}

variable "woodpecker_forgejo_secret" {
  description = "Forgejo OAuth client secret for Woodpecker CI"
  type        = string
  sensitive   = true
}

variable "woodpecker_admin_users" {
  description = "Comma-separated Forgejo usernames with Woodpecker admin rights"
  type        = string
  default     = "forgejo_admin"
}

variable "harbor_admin_password" {
  description = "Harbor admin password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.harbor_admin_password) >= 8
    error_message = "harbor_admin_password must be at least 8 characters."
  }
}

variable "harbor_secret_key" {
  description = "Harbor 16-char encryption key for internal secrets (must be preserved)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.harbor_secret_key) == 16
    error_message = "harbor_secret_key must be exactly 16 characters."
  }
}
