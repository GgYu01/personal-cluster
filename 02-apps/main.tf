# 02-apps/main.tf (DEFINITIVE FINAL VERSION - Correct Helm-based deployment)

# This file implements a robust, two-stage installation for ArgoCD using the helm_release provider.
# Stage 1: Install only the CRDs and wait for them to be established.
# Stage 2: Install the rest of the ArgoCD application, depending on the successful completion of Stage 1.

# --- STAGE 1: Install ArgoCD CRDs ---
# This release only installs the Custom Resource Definitions.
resource "helm_release" "argocd_crds" {
  name             = "argocd-crds"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.2.4" # Using the version you specified
  namespace        = "argocd"
  create_namespace = true # Ensure the namespace exists before installation

  # Values to instruct the chart to ONLY install CRDs.
  values = [
    yamlencode({
      crds = {
        install = true
      }
      # Disable all other components for this release
      controller     = { enabled = false }
      server         = { enabled = false }
      repoServer     = { enabled = false }
      applicationSet = { enabled = false }
      dex            = { enabled = false }
      redis          = { enabled = false }
      "redis-ha"     = { enabled = false }
      notifications  = { enabled = false }
    })
  ]

  # This is crucial for idempotency and upgrades.
  # It tells Terraform to wait until the Helm release is fully deployed.
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
  namespace        = "argocd" # Deploy into the same, already-created namespace
  create_namespace = false    # Namespace is already created by the CRD release

  # Values for the main application.
  values = [
    yamlencode({
      # CRITICAL: Do NOT reinstall CRDs. They are managed by the first release.
      crds = {
        install = false
      }
      # Set the admin password to "password" as you requested.
      # The value is the bcrypt hash of "password".
      configs = {
        secret = {
          argocdServerAdminPassword = "$2a$10$r8i.p3qV5.IqLgqvB..31eL9g/XyJc5lqJzCrHw5TKSg2Kx5i/fWu" # bcrypt hash for "password"
        }
        # You can add other ArgoCD configurations here under 'cm' or 'params' if needed.
      }
      # Ensure all components are enabled (this is the default, but explicit is better)
      controller     = { enabled = true }
      server         = { enabled = true }
      repoServer     = { enabled = true }
      applicationSet = { enabled = true }
      dex            = { enabled = true } # Dex is enabled by default in the chart
      redis          = { enabled = true } # Redis is enabled by default in the chart
    })
  ]

  timeout = 1200 # Increase timeout to allow for image pulling and pod startup
  wait    = true # Wait for the main application to be fully ready
}

# --- STAGE 3: Create the Root Application ---
# This resource creates the single 'root' Application CR that bootstraps your GitOps repository.
# It depends on the main ArgoCD release being ready.
resource "kubectl_manifest" "root_app" {
  depends_on = [
    helm_release.argocd
  ]

  # This uses the template file you already have.
  yaml_body = templatefile("${path.module}/root-app-template.yaml", {
    gitops_repo_url = var.gitops_repo_url
  })
}
