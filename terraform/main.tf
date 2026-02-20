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

# --- Monitoring Namespace ---

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

# --- Monitoring: kube-prometheus-stack ---

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "82.0.0"
  timeout    = 600

  values = [yamlencode({
    kubeControllerManager = { enabled = false }
    kubeEtcd              = { enabled = false }
    kubeProxy             = { enabled = false }
    kubeScheduler         = { enabled = false }

    grafana = {
      adminPassword = var.grafana_admin_password
      persistence = {
        enabled          = true
        size             = "2Gi"
        storageClassName = "local-path"
      }
      resources = {
        limits   = { memory = "256Mi" }
        requests = { cpu = "50m", memory = "128Mi" }
      }
      sidecar = {
        dashboards  = { enabled = true, searchNamespace = "ALL" }
        datasources = { enabled = true, searchNamespace = "ALL" }
      }
    }

    prometheus = {
      prometheusSpec = {
        retention                               = "15d"
        retentionSize                           = "10GB"
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        serviceMonitorSelectorNilUsesHelmValues = false
        resources = {
          limits   = { memory = "1Gi" }
          requests = { cpu = "200m", memory = "512Mi" }
        }
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "local-path"
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "15Gi" } }
            }
          }
        }
      }
    }

    alertmanager = {
      alertmanagerSpec = {
        resources = {
          limits   = { memory = "128Mi" }
          requests = { cpu = "10m", memory = "64Mi" }
        }
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "local-path"
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "1Gi" } }
            }
          }
        }
      }
    }

    kube-state-metrics = {
      resources = {
        limits   = { memory = "128Mi" }
        requests = { cpu = "10m", memory = "32Mi" }
      }
    }

    nodeExporter = {
      resources = {
        limits   = { memory = "64Mi" }
        requests = { cpu = "20m", memory = "32Mi" }
      }
    }
  })]
}

# --- Monitoring: Loki ---

resource "helm_release" "loki_stack" {
  name       = "loki-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = "2.10.3"
  timeout    = 600

  values = [yamlencode({
    grafana = { enabled = false }
    loki = {
      persistence = {
        enabled          = true
        size             = "10Gi"
        storageClassName = "local-path"
      }
      resources = {
        limits   = { memory = "256Mi" }
        requests = { cpu = "50m", memory = "128Mi" }
      }
      config = {
        table_manager = {
          retention_deletes_enabled = true
          retention_period          = "168h"
        }
      }
    }
    promtail = {
      resources = {
        limits   = { memory = "128Mi" }
        requests = { cpu = "20m", memory = "64Mi" }
      }
    }
  })]
}

# --- Grafana Tailscale Funnel ---

resource "kubernetes_ingress_v1" "grafana_funnel" {
  metadata {
    name      = "grafana-funnel"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    annotations = {
      "tailscale.com/funnel" = "true"
    }
  }

  spec {
    ingress_class_name = "tailscale"

    default_backend {
      service {
        name = "kube-prometheus-stack-grafana"
        port {
          number = 80
        }
      }
    }

    tls {
      hosts = ["grafana"]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack, helm_release.tailscale_operator]
}
