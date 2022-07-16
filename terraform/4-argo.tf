resource "kubernetes_namespace" "namespace1" {
  metadata {
    name = "argo"
  }
}

// regular argo installation 
data "kubectl_file_documents" "manifests" {
  content = file("${path.module}/argo.yaml")
}

resource "kubectl_manifest" "argo" {
  count              = length(data.kubectl_file_documents.manifests.documents)
  yaml_body          = element(data.kubectl_file_documents.manifests.documents, count.index)
  override_namespace = kubernetes_namespace.namespace1.metadata.0.name
  depends_on = [
    google_container_node_pool.npool1
  ]
}

// argo modifications  (changed: names, LoadBalancers, namespaces )
resource "kubernetes_service_account" "argo_server" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}"
  }
  depends_on = [
    google_container_node_pool.npool1
  ]
}

resource "kubernetes_role" "argo_server_role" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}-role"
  }
  rule {
    verbs      = ["get", "watch", "list"]
    api_groups = [""]
    resources  = ["configmaps"]
  }
  rule {
    verbs      = ["get", "create"]
    api_groups = [""]
    resources  = ["secrets"]
  }
  rule {
    verbs      = ["get", "list", "watch", "delete"]
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log"]
  }
  rule {
    verbs      = ["watch", "create", "patch"]
    api_groups = [""]
    resources  = ["events"]
  }
  rule {
    verbs      = ["get", "list"]
    api_groups = [""]
    resources  = ["serviceaccounts"]
  }
  rule {
    verbs      = ["create", "get", "list", "watch", "update", "patch", "delete"]
    api_groups = ["argoproj.io"]
    resources  = ["eventsources", "sensors", "workflows", "workfloweventbindings", "workflowtemplates", "cronworkflows", "cronworkflows/finalizers"]
  }
}

resource "kubernetes_cluster_role" "argo_server_clusterworkflowtemplate_role" {
  metadata {
    name = "argo-server-${var.name}-clusterworkflowtemplate-role"
  }
  rule {
    verbs      = ["create", "delete", "watch", "get", "list", "watch"]
    api_groups = ["argoproj.io"]
    resources  = ["clusterworkflowtemplates", "clusterworkflowtemplates/finalizers"]
  }
}

resource "kubernetes_role_binding" "argo_server_binding" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}-binding"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argo-server-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "argo-server-${var.name}-role"
  }
}

resource "kubernetes_cluster_role_binding" "argo_server_clusterworkflowtemplate_role_binding" {
  metadata {
    name = "argo-server-${var.name}-clusterworkflowtemplate-role-binding"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argo-server-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "argo-server-${var.name}-clusterworkflowtemplate-role"
  }
}

resource "kubernetes_secret" "argo_server_sso" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}-sso"
    labels = {
      app = "argo-server-${var.name}"
    }
  }
}

resource "kubernetes_service" "argo_server" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}"
  }
  spec {
    port {
      name        = "web"
      port        = 2746
      target_port = "2746"
    }
    selector = {
      app = "argo-server-${var.name}"
    }
    type                    = "LoadBalancer"
    session_affinity        = "None"
    external_traffic_policy = "Cluster"
  }
  depends_on = [
    google_container_node_pool.npool1
  ]
}

resource "kubernetes_deployment" "argo_server" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "argo-server-${var.name}"
  }
  spec {
    selector {
      match_labels = {
        app = "argo-server-${var.name}"
      }
    }
    template {
      metadata {
        namespace = kubernetes_namespace.namespace1.metadata.0.name
        labels = {
          app = "argo-server-${var.name}"
        }
      }
      spec {
        volume {
          name = "tmp"
        }
        container {
          name  = "argo-server-${var.name}"
          image = "argoproj/argocli:v3.0.3"
          args  = ["server", "--namespaced", "--auth-mode", "server", "--auth-mode", "client"]
          port {
            name           = "web"
            container_port = 2746
          }
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
          readiness_probe {
            http_get {
              path   = "/"
              port   = "2746"
              scheme = "HTTPS"
            }
            initial_delay_seconds = 10
            period_seconds        = 20
          }
          security_context {
            capabilities {
              drop = ["ALL"]
            }
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
        service_account_name = "argo-server-${var.name}"
        security_context {
          run_as_non_root = true
        }
      }
    }
  }
  depends_on = [
    google_container_node_pool.npool1
  ]
}