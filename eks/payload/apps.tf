data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "kubernetes_deployment" "app" {
  for_each = toset(data.terraform_remote_state.eks.outputs.apps_list)
  metadata {
    name = each.key
    labels = {
      App = each.key
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        App = each.key
      }
    }
    template {
      metadata {
        labels = {
          App = each.key
        }
      }
      spec {
        container {
          image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${each.key}-app:latest"
          name  = "${each.key}-app"
          port {
            container_port = 80
          }
          env {
              name = "MYSQL_HOST"
              value = data.terraform_remote_state.rds.outputs.instance_address
          }
          env {
              name = "MYSQL_USER"
              value = data.terraform_remote_state.rds.outputs.instance_username
          }
          env {
              name = "MYSQL_PASSWORD"
              value = data.terraform_remote_state.rds.outputs.instance_random_password
          }
          env {
              name = "MYSQL_DATABASE"
              value = data.terraform_remote_state.rds.outputs.instance_name
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "scaler" {
  for_each = toset(data.terraform_remote_state.eks.outputs.apps_list)
  metadata {
    name = "${each.key}app-autoscaler"
  }
  spec {
    min_replicas = 1
    max_replicas = 2
    scale_target_ref {
#      api_version = "extensions/v1beta1"
#      api_version = "apps/v1"
      api_version = "autoscaling/v1"
      kind        = "deployment"
      name        = each.key
    }
    target_cpu_utilization_percentage = 20
  }
}

resource "kubernetes_service" "app-svc" {
  for_each = toset(data.terraform_remote_state.eks.outputs.apps_list)
  metadata {
    name = "${each.key}-app"
  }
  spec {
    selector = {
      App = kubernetes_deployment.app[each.key].spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 8000
    }
    type = "ClusterIP"
  }
}
