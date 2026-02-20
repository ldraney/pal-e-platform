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

# --- Tailscale ACL Policy ---

resource "tailscale_acl" "this" {
  acl = jsonencode({
    grants = [
      {
        src = ["*"]
        dst = ["*"]
        ip  = ["*"]
      }
    ]

    ssh = [
      {
        action = "check"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = ["autogroup:nonroot", "root"]
      }
    ]

    nodeAttrs = [
      {
        target = ["autogroup:member", "tag:k8s"]
        attr   = ["funnel"]
      }
    ]

    tagOwners = {
      "tag:k8s" = ["autogroup:admin"]
    }
  })

  # Terraform is the source of truth — manual admin console edits will be overwritten
  overwrite_existing_content = true
  # WARNING: resets the ENTIRE tailnet ACL to defaults on destroy (safe while this is the sole ACL manager)
  reset_acl_on_destroy = true
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

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
    type  = "string"
  }
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

# --- Grafana Loki Datasource ---

resource "kubernetes_config_map_v1" "grafana_loki_datasource" {
  metadata {
    name      = "grafana-loki-datasource"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [{
        name   = "Loki"
        type   = "loki"
        url    = "http://loki-stack:3100"
        access = "proxy"
      }]
    })
  }

  depends_on = [helm_release.loki_stack, helm_release.kube_prometheus_stack]
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

  depends_on = [helm_release.kube_prometheus_stack, helm_release.tailscale_operator, tailscale_acl.this]
}

# --- Forgejo Namespace ---

resource "kubernetes_namespace_v1" "forgejo" {
  metadata {
    name = "forgejo"
    labels = {
      name = "forgejo"
    }
  }
}

# --- Forgejo ---

resource "helm_release" "forgejo" {
  name      = "forgejo"
  namespace = kubernetes_namespace_v1.forgejo.metadata[0].name
  chart     = "oci://code.forgejo.org/forgejo-helm/forgejo"
  version   = "16.2.0"
  timeout   = 600

  values = [yamlencode({
    gitea = {
      admin = {
        username     = var.forgejo_admin_username
        email        = var.forgejo_admin_email
        passwordMode = "keepUpdated"
      }
      config = {
        server = {
          DOMAIN     = "forgejo.${var.tailscale_domain}"
          ROOT_URL   = "https://forgejo.${var.tailscale_domain}/"
          SSH_DOMAIN = "forgejo.${var.tailscale_domain}"
        }
        webhook = {
          ALLOWED_HOST_LIST = "external,loopback"
        }
      }
    }

    persistence = {
      enabled      = true
      size         = "10Gi"
      storageClass = "local-path"
    }

    service = {
      http = { type = "ClusterIP", port = 80 }
      ssh  = { type = "ClusterIP", port = 22 }
    }

    ingress = { enabled = false }

    resources = {
      requests = { cpu = "100m", memory = "512Mi" }
      limits   = { memory = "2Gi" }
    }
  })]

  set_sensitive {
    name  = "gitea.admin.password"
    value = var.forgejo_admin_password
    type  = "string"
  }
}

# --- Forgejo Tailscale Funnel ---

resource "kubernetes_ingress_v1" "forgejo_funnel" {
  metadata {
    name      = "forgejo-funnel"
    namespace = kubernetes_namespace_v1.forgejo.metadata[0].name
    annotations = {
      "tailscale.com/funnel" = "true"
    }
  }

  spec {
    ingress_class_name = "tailscale"

    default_backend {
      service {
        name = "forgejo-http"
        port {
          number = 80
        }
      }
    }

    tls {
      hosts = ["forgejo"]
    }
  }

  depends_on = [helm_release.forgejo, helm_release.tailscale_operator, tailscale_acl.this]
}

# --- Woodpecker CI Namespace ---

resource "kubernetes_namespace_v1" "woodpecker" {
  metadata {
    name = "woodpecker"
    labels = {
      name = "woodpecker"
    }
  }
}

# --- Woodpecker CI ---

resource "helm_release" "woodpecker" {
  name      = "woodpecker"
  namespace = kubernetes_namespace_v1.woodpecker.metadata[0].name
  chart     = "oci://ghcr.io/woodpecker-ci/helm/woodpecker"
  version   = "3.5.1"
  timeout   = 600

  values = [yamlencode({
    server = {
      env = {
        WOODPECKER_HOST                = "https://woodpecker.${var.tailscale_domain}"
        WOODPECKER_ADMIN               = var.woodpecker_admin_users
        WOODPECKER_FORGEJO             = "true"
        WOODPECKER_FORGEJO_URL         = "https://forgejo.${var.tailscale_domain}"
        WOODPECKER_FORGEJO_SKIP_VERIFY = "false"
      }

      statefulSet = {
        replicaCount = 1
      }

      persistentVolume = {
        enabled      = true
        size         = "5Gi"
        storageClass = "local-path"
      }

      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { memory = "512Mi" }
      }
    }

    agent = {
      enabled      = true
      replicaCount = 1

      env = {
        WOODPECKER_BACKEND                   = "kubernetes"
        WOODPECKER_BACKEND_K8S_NAMESPACE     = "woodpecker"
        WOODPECKER_BACKEND_K8S_STORAGE_CLASS = "local-path"
        WOODPECKER_BACKEND_K8S_VOLUME_SIZE   = "1Gi"
      }

      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { memory = "256Mi" }
      }
    }
  })]

  set_sensitive {
    name  = "server.env.WOODPECKER_FORGEJO_CLIENT"
    value = var.woodpecker_forgejo_client
    type  = "string"
  }

  set_sensitive {
    name  = "server.env.WOODPECKER_FORGEJO_SECRET"
    value = var.woodpecker_forgejo_secret
    type  = "string"
  }

  depends_on = [helm_release.forgejo]
}

# --- Woodpecker CI Tailscale Funnel ---

resource "kubernetes_ingress_v1" "woodpecker_funnel" {
  metadata {
    name      = "woodpecker-funnel"
    namespace = kubernetes_namespace_v1.woodpecker.metadata[0].name
    annotations = {
      "tailscale.com/funnel" = "true"
    }
  }

  spec {
    ingress_class_name = "tailscale"

    default_backend {
      service {
        name = "woodpecker-server"
        port {
          number = 80
        }
      }
    }

    tls {
      hosts = ["woodpecker"]
    }
  }

  depends_on = [helm_release.woodpecker, helm_release.tailscale_operator, tailscale_acl.this]
}

# --- Harbor Registry Namespace ---

resource "kubernetes_namespace_v1" "harbor" {
  metadata {
    name = "harbor"
    labels = {
      name = "harbor"
    }
  }
}

# --- Harbor Container Registry ---

resource "helm_release" "harbor" {
  name       = "harbor"
  namespace  = kubernetes_namespace_v1.harbor.metadata[0].name
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  version    = "1.18.2"
  timeout    = 600

  values = [yamlencode({
    expose = {
      type = "clusterIP"
      clusterIP = {
        name = "harbor"
        ports = {
          httpPort = 80
        }
      }
      tls = {
        enabled = false
      }
    }

    externalURL = "https://harbor.${var.tailscale_domain}"

    trivy = {
      enabled = false
    }

    metrics = {
      enabled = true
      serviceMonitor = {
        enabled = true
      }
    }

    persistence = {
      enabled = true
      persistentVolumeClaim = {
        registry = {
          storageClass = "local-path"
          size         = "20Gi"
        }
        jobservice = {
          jobLog = {
            storageClass = "local-path"
            size         = "1Gi"
          }
        }
        database = {
          storageClass = "local-path"
          size         = "2Gi"
        }
        redis = {
          storageClass = "local-path"
          size         = "1Gi"
        }
      }
    }

    database = { type = "internal" }
    redis    = { type = "internal" }

    core = {
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { memory = "512Mi" }
      }
    }

    portal = {
      resources = {
        requests = { cpu = "20m", memory = "32Mi" }
        limits   = { memory = "128Mi" }
      }
    }

    registry = {
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { memory = "256Mi" }
      }
    }

    jobservice = {
      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { memory = "256Mi" }
      }
    }

    nginx = {
      resources = {
        requests = { cpu = "20m", memory = "32Mi" }
        limits   = { memory = "128Mi" }
      }
    }
  })]

  set_sensitive {
    name  = "harborAdminPassword"
    value = var.harbor_admin_password
    type  = "string"
  }

  set_sensitive {
    name  = "secretKey"
    value = var.harbor_secret_key
    type  = "string"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# --- Harbor Tailscale Funnel ---

resource "kubernetes_ingress_v1" "harbor_funnel" {
  metadata {
    name      = "harbor-funnel"
    namespace = kubernetes_namespace_v1.harbor.metadata[0].name
    annotations = {
      "tailscale.com/funnel" = "true"
    }
  }

  spec {
    ingress_class_name = "tailscale"

    default_backend {
      service {
        name = "harbor"
        port {
          number = 80
        }
      }
    }

    tls {
      hosts = ["harbor"]
    }
  }

  depends_on = [helm_release.harbor, helm_release.tailscale_operator, tailscale_acl.this]
}
