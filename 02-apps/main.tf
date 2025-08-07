# 02-apps/main.tf (DEFINITIVE FINAL VERSION - Correct for_each Syntax)

# STEP 1: RENDER the CRD templates from the ArgoCD Helm chart into a multi-document YAML string.
data "helm_template" "argocd_crds_rendered" {
  name         = "argocd-crds-rendered"
  repository   = "https://argoproj.github.io/argo-helm"
  chart        = "argo-cd"
  version      = "8.2.4"
  kube_version = "1.33.3"

  values = [
    yamlencode({
      crds = {
        install = true
      }
      controller     = { enabled = false }
      server         = { enabled = false }
      repoServer     = { enabled = false }
      applicationSet = { enabled = false }
      dex            = { enabled = false }
      redis          = { enabled = false }
      redis-ha       = { enabled = false }
    })
  ]
}

# STEP 2: SPLIT the rendered multi-document YAML string into a list of individual YAML documents.
data "kubectl_file_documents" "argocd_crds_split" {
  content = data.helm_template.argocd_crds_rendered.manifest
}

# STEP 3: APPLY each individual CRD document as a separate, tracked resource.
resource "kubectl_manifest" "argocd_crds" {
  # CRITICAL FIX: Convert the list of documents to a set of strings, which is a valid type for for_each.
  for_each  = toset(data.kubectl_file_documents.argocd_crds_split.documents)
  yaml_body = each.value
}

# STEP 4: Deterministically WAIT for ALL CRDs to be established.
resource "null_resource" "wait_for_argocd_crds" {
  depends_on = [kubectl_manifest.argocd_crds]

  provisioner "local-exec" {
    # Chain commands with '&&' for robust error handling.
    command = <<EOT
      echo "Waiting for ArgoCD CRDs to be established..." && \
      kubectl wait --for=condition=established --timeout=120s crd/applications.argoproj.io && \
      kubectl wait --for=condition=established --timeout=120s crd/applicationsets.argoproj.io && \
      kubectl wait --for=condition=established --timeout=120s crd/appprojects.argoproj.io && \
      echo "ArgoCD CRDs are established."
    EOT
  }
}

# STEP 5: Install the ArgoCD application itself.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "8.2.4"
  timeout          = 1200
  wait             = true

  values = [
    yamlencode({
      crds = {
        install = false
      }
      configs = {
        secret = {
          argocdServerAdminPassword = "$2a$10$Ep1xq3oPnHwsIwoQKPD1iO7N2vUU23zUS18BVjiY8fmrA3e3VxO62" # "password"
        }
      }
    })
  ]

  depends_on = [
    null_resource.wait_for_argocd_crds
  ]
}

# STEP 6: Create the single root Application object.
resource "kubectl_manifest" "root_app" {
  yaml_body = templatefile("${path.module}/root-app-template.yaml", {
    gitops_repo_url = var.gitops_repo_url
  })

  depends_on = [
    helm_release.argocd
  ]
}