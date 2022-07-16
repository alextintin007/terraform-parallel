resource "kubernetes_config_map" "nginx_conf" {
  metadata {
    name      = "basic-config"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
  }
  data = {
    "nginx.conf" = "server {\nlocation / {\nroot /usr/share/nginx/html/;\nindex index.html;\nautoindex on;}}"
  }
}

resource "kubernetes_deployment" "http_fileserver" {
  metadata {
    name      = "http-fileserver-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    labels = {
      service = "http-fileserver-${var.name}"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        service = "http-fileserver-${var.name}"
      }
    }
    template {
      metadata {
        labels = {
          service = "http-fileserver-${var.name}"
        }
      }
      spec {
        volume {
          name = "volume-output"
          persistent_volume_claim {
            claim_name = "nfs-${var.name}"
          }
        }
        volume {
          name = "basic-config"
          config_map {
            name = "basic-config"
          }
        }
        container {
          name  = "file-storage-container"
          image = "nginx"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "volume-output"
            mount_path = "/usr/share/nginx/html"
          }
          volume_mount {
            name       = "basic-config"
            mount_path = "/etc/nginx/conf.d"
          }
          lifecycle {
            post_start {
              exec {
                command = ["rm", "/usr/share/nginx/html/index.html"]
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    google_container_node_pool.npool1
  ]
}

resource "kubernetes_service" "http_fileserver" {
  metadata {
    name      = "http-fileserver-${var.name}"
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    labels = {
      service = "http-fileserver-${var.name}"
    }
  }
  spec {
    port {
      protocol    = "TCP"
      port        = 80
      target_port = "80"
      node_port   = 32703
    }
    selector = {
      service = "http-fileserver-${var.name}"
    }
    type                    = "LoadBalancer"
    session_affinity        = "None"
    external_traffic_policy = "Cluster"
  }
  depends_on = [
    google_container_node_pool.npool1
  ]
}

resource "kubernetes_cluster_role_binding" "rb" {
  metadata {
    name = var.name
  }
  subject {
    kind = "User"
    name = var.email
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

resource "kubernetes_config_map" "artifact_repositories" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "artifact-repositories"
    annotations = {
      "workflows.argoproj.io/default-artifact-repository" = "default-v1"
    }
  }
  data = {
    default-v1 = "archiveLogs: true\ns3:\n  bucket: my-bucket\n  endpoint: minio-${var.name}:9000\n  insecure: true\n  accessKeySecret:\n    name: my-minio-${var.name}-cred\n    key: accesskey\n  secretKeySecret:\n    name: my-minio-${var.name}-cred\n    key: secretkey\n"
    my-key     = "archiveLogs: true\ns3:\n  bucket: my-bucket\n  endpoint: minio-${var.name}:9000\n  insecure: true\n  accessKeySecret:\n    name: my-minio-${var.name}-cred\n    key: accesskey\n  secretKeySecret:\n    name: my-minio-${var.name}-cred\n    key: secretkey\n"
  }
}

resource "kubernetes_config_map" "workflow_controller_configmap" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "workflow-controller-configmap"
  }

  data = {
    artifactRepository        = "archiveLogs: true\ns3:\n  bucket: my-bucket\n  endpoint: minio-${var.name}:9000\n  insecure: true\n  accessKeySecret:\n    name: my-minio-${var.name}-cred\n    key: accesskey\n  secretKeySecret:\n    name: my-minio-${var.name}-cred\n    key: secretkey\n"
    containerRuntimeExecutor  = "docker"
    containerRuntimeExecutors = "- name: k8sapi\n  selector:\n    matchLabels:\n      workflows.argoproj.io/container-runtime-executor: k8sapi\n"
    executor                  = "resources:\n  requests:\n    cpu: 10m\n    memory: 64Mi\n"
    links                     = "- name: Workflow Link\n  scope: workflow\n  url: http://logging-facility?namespace=$${metadata.namespace}&workflowName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Pod Link\n  scope: pod\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Pod Logs Link\n  scope: pod-logs\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Event Source Logs Link\n  scope: event-source-logs\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n- name: Sensor Logs Link\n  scope: sensor-logs\n  url: http://logging-facility?namespace=$${metadata.namespace}&podName=$${metadata.name}&startedAt=$${status.startedAt}&finishedAt=$${status.finishedAt}\n"
    metricsConfig             = "disableLegacy: true\nenabled: true\npath: /metrics\nport: 9090\n"
    persistence               = "connectionPool:\n  maxIdleConns: 100\n  maxOpenConns: 0\n  connMaxLifetime: 0s\nnodeStatusOffLoad: true\narchive: true\narchiveTTL: 7d\npostgresql:\n  host: postgres\n  port: 5432\n  database: postgres\n  tableName: argo_workflows\n  userNameSecret:\n    name: argo-postgres-config\n    key: username\n  passwordSecret:\n    name: argo-postgres-config\n    key: password\n"
  }
}

resource "kubernetes_secret" "my_minio_cred" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "my-minio-${var.name}-cred"
    labels = {
      app = "minio-${var.name}"
    }
  }
  data = {
    accesskey = "admin"
    secretkey = "password"
  }
  type = "Opaque"
}

resource "kubernetes_service" "minio" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "minio-${var.name}"
    labels = {
      app = "minio-${var.name}"
    }
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 9000
      target_port = "9000"
    }
    selector = {
      app = "minio-${var.name}"
    }
  }
  depends_on = [
    google_container_node_pool.npool1
  ]
}

resource "kubernetes_deployment" "minio" {
  metadata {
    namespace = kubernetes_namespace.namespace1.metadata.0.name
    name      = "minio-${var.name}"
    labels = {
      app = "minio-${var.name}"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "minio-${var.name}"
      }
    }
    template {
      metadata {
        namespace = kubernetes_namespace.namespace1.metadata.0.name
        labels = {
          app = "minio-${var.name}"
        }
      }
      spec {
        container {
          name    = "main"
          image   = "minio/minio:RELEASE.2019-12-17T23-16-33Z"
          command = ["minio", "server", "/data"]
          port {
            container_port = 9000
          }
          env {
            name  = "MINIO_ACCESS_KEY"
            value = "admin"
          }
          env {
            name  = "MINIO_SECRET_KEY"
            value = "password"
          }
          liveness_probe {
            http_get {
              path = "/minio/health/live"
              port = "9000"
            }

            initial_delay_seconds = 5
            period_seconds        = 10
          }
          readiness_probe {
            http_get {
              path = "/minio/health/ready"
              port = "9000"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
          lifecycle {
            post_start {
              exec {
                command = ["mkdir", "-p", "/data/my-bucket"]
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    google_container_node_pool.npool1
  ]
}