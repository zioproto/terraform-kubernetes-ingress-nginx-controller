resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "${local.name}"

    labels {
      "app.kubernetes.io/name"    = "${local.name}"
      "app.kubernetes.io/part-of" = "${local.name}"
    }
  }
}

resource "kubernetes_service_account" "nginx_ingress_serviceaccount" {
  metadata {
    name      = "nginx-ingress-serviceaccount"
    namespace = "${kubernetes_namespace.ingress_nginx.metadata.0.name}"

    labels {
      "app.kubernetes.io/name"    = "${local.name}"
      "app.kubernetes.io/part-of" = "${local.name}"
    }
  }
}

resource "kubernetes_deployment" "nginx_ingress_controller" {
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "${kubernetes_namespace.ingress_nginx.metadata.0.name}"

    labels {
      "app.kubernetes.io/name"    = "${local.name}"
      "app.kubernetes.io/part-of" = "${local.name}"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels {
        "app.kubernetes.io/name"    = "${local.name}"
        "app.kubernetes.io/part-of" = "${local.name}"
      }
    }

    template {
      metadata {
        labels {
          "app.kubernetes.io/name"    = "${local.name}"
          "app.kubernetes.io/part-of" = "${local.name}"
        }

        annotations {
          "prometheus.io/port"   = "${local.probe_port}"
          "prometheus.io/scrape" = "true"
        }
      }

      spec {
        volume {
          name = "${kubernetes_service_account.nginx_ingress_serviceaccount.default_secret_name}"

          secret {
            secret_name = "${kubernetes_service_account.nginx_ingress_serviceaccount.default_secret_name}"
          }
        }

        container {
          name  = "nginx-ingress-controller"
          image = "${var.image}:${var.image_version}"
          args  = ["/nginx-ingress-controller", "--configmap=$(POD_NAMESPACE)/nginx-configuration", "--tcp-services-configmap=$(POD_NAMESPACE)/tcp-services", "--udp-services-configmap=$(POD_NAMESPACE)/udp-services", "--publish-service=$(POD_NAMESPACE)/ingress-nginx", "--annotations-prefix=nginx.ingress.kubernetes.io"]

          port {
            name           = "http"
            container_port = 80
          }

          port {
            name           = "https"
            container_port = 443
          }

          env {
            name = "POD_NAME"

            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = "${local.probe_port}"
              scheme = "HTTP"
            }

            initial_delay_seconds = 10
            timeout_seconds       = 10
            period_seconds        = 10
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = "${local.probe_port}"
              scheme = "HTTP"
            }

            timeout_seconds   = 10
            period_seconds    = 10
            success_threshold = 1
            failure_threshold = 3
          }

          security_context {
            run_as_user                = 33
            allow_privilege_escalation = true
          }

          volume_mount {
            name       = "${kubernetes_service_account.nginx_ingress_serviceaccount.default_secret_name}"
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            read_only  = true
          }
        }

        service_account_name = "${kubernetes_service_account.nginx_ingress_serviceaccount.metadata.0.name}"
      }
    }
  }
}
