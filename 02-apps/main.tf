# 02-apps/main.tf (DEFINITIVE FINAL VERSION v2 - Correct Helm-based deployment with CRD separation)

# This file implements a robust, two-stage installation for ArgoCD using the helm_release provider.
# The key change is to use the ArgoCD chart's dedicated `crds.install=true` feature in a way
# that avoids creating non-CRD resources in the first stage.

# --- STAGE 1: Install ArgoCD CRDs ONLY ---
# This release *only* installs the Custom Resource Definitions.
# We achieve this by enabling `crds.install` and disabling almost everything else
# at the top level of the Helm chart values.
resource "helm_release" "argocd_crds" {
  name             = "argocd-crds"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.2.4"
  namespace        = "argocd"
  create_namespace = true

  # CRITICAL FIX: Use a minimal set of values. The chart is designed
  # such that if `crds.install` is true, it should only install CRDs if other
  # components are disabled. We will explicitly disable them to be certain.
  values = [
    yamlencode({
      crds = {
        install = true
        # Keep the CRDs even if this Helm release is uninstalled
        keep = true
      }
      # Explicitly disable all other components to prevent ownership conflicts.
      controller     = { enabled = false }
      server         = { enabled = false }
      repoServer     = { enabled = false }
      dex            = { enabled = false }
      redis          = { enabled = false }
      "redis-ha"     = { enabled = false }
      applicationSet = { enabled = false }
      notifications  = { enabled = false }
    })
  ]

  wait = true
}

# --- STAGE 2: Install ArgoCD Application ---
# This release installs the main ArgoCD application components.
# It explicitly depends on the CRDs being successfully installed first.
resource "helm_release" "argocd" {
  depends_on = [
    helm_release.argocd_crds
  ]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.2.4"
  namespace        = "argocd"
  create_namespace = false # Namespace is already created

  # Values for the main application.
  values = [
    yamlencode({
      # CRITICAL: Do NOT let this release manage CRDs.
      crds = {
        install = false
      }
      # Set the admin password to "password".
      configs = {
        secret = {
          # bcrypt hash for "password"
          argocdServerAdminPassword = "$2a$10$r8i.p3qV5.IqLgqvB..31eL9g/XyJc5lqJzCrHw5TKSg2Kx5i/fWu"
        }
      }
      # All other components use their default (enabled) state.
    })
  ]

  timeout = 1200
  wait    = true
}

# --- STAGE 3: Create the Root Application ---
# This resource creates the single 'root' Application CR that bootstraps your GitOps repository.
resource "kubectl_manifest" "root_app" {
  depends_on = [
    helm_release.argocd
  ]

  yaml_body = templatefile("${path.module}/root-app-template.yaml", {
    gitops_repo_url = var.gitops_repo_url
  })
}
