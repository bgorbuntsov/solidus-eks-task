resource "kubectl_manifest" "ingress-paths" {
  for_each  = toset(data.terraform_remote_state.eks.outputs.apps_list)
  yaml_body = templatefile("./ingress-path.yaml", { domainname = data.terraform_remote_state.eks.outputs.domainname, appname = each.key })
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
}
