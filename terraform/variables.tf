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
