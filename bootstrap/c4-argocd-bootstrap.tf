# bootstrap/c4-argocd-bootstrap.tf

# 动态配置Kubernetes和Helm Provider，使用刚刚获取的kubeconfig
provider "kubernetes" {
  alias              = "k3s"
  config_path        = "${path.module}/k3s.yaml"
  insecure           = true # K3s自签名证书
}

provider "helm" {
  alias = "k3s"
  kubernetes {
    config_path = "${path.module}/k3s.yaml"
    insecure    = true
  }
}

# 部署ArgoCD
resource "helm_release" "argocd" {
  provider   = helm.k3s
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
  version    = "5.29.1"

  # 等待K3s安装完成
  depends_on = [null_resource.k3s_install]
}

# 部署ArgoCD的"App of Apps"
# 这会告诉ArgoCD去监控我们Git仓库的kubernetes/charts目录
resource "kubernetes_manifest" "app_of_apps" {
  provider = kubernetes.k3s
  manifest = yamldecode(file("../kubernetes/apps/root-app.yaml"))
  
  # 等待ArgoCD部署完成
  depends_on = [helm_release.argocd]
}