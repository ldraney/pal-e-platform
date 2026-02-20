# --- Namespaces ---

resource "kubernetes_namespace_v1" "tailscale" {
  metadata {
    name = "tailscale"
    labels = {
      name = "tailscale"
    }
  }
}

# --- Tailscale Operator ---

resource "helm_release" "tailscale_operator" {
  name       = "tailscale-operator"
  namespace  = kubernetes_namespace_v1.tailscale.metadata[0].name
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = "1.94.2"

  set {
    name  = "oauth.clientId"
    value = var.tailscale_oauth_client_id
  }

  set_sensitive {
    name  = "oauth.clientSecret"
    value = var.tailscale_oauth_client_secret
  }

  set {
    name  = "operatorConfig.defaultTags"
    value = "tag:k8s"
  }
}
