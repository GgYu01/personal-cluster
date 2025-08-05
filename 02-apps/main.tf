# 02-apps/main.tf

# This local block reconstructs the values needed for ArgoCD,
# which were previously in the monolithic locals.tf.
locals {
  argocd_app_values = yamlencode({
    global = {
      domain = var.cluster_base_domain
    }
    casdoor = {
      host = "casdoor.${var.cluster_base_domain}"
    }
    minio = {
      host = "s3.${var.cluster_base_domain}"
    }
    n8n = {
      host = "n8n.${var.cluster_base_domain}"
    }
  })
}

# Deploy ArgoCD using the Helm provider.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "8.2.4" # Using a recent stable version

  # --- ADD THIS BLOCK ---
  # This block provides custom values to the ArgoCD Helm chart.
  # We use it to dynamically configure and enable the Ingress resource,
  # which exposes the ArgoCD server UI via Traefik.
  values = [
    yamlencode({
      # The "server" block configures the argocd-server component.
      server = {
        # The "ingress" block specifically controls the Ingress resource.
        ingress = {
          # Enable the creation of an Ingress object.
          enabled = true

          # Set the IngressClass to "traefik". This is a CRITICAL step.
          # It explicitly tells Kubernetes that this Ingress should be managed
          # by the Traefik Ingress Controller, not any other controller that
          # might be running in the cluster.
          ingressClassName = "traefik"

          # Define the hostnames that this Ingress rule applies to.
          hosts = [
            "argocd.${var.cluster_base_domain}"
          ]

          # For simplicity and initial verification, we will not configure TLS yet.
          # The connection will be plain HTTP.
          # tls = [] # This line can be omitted or left empty.
        }
      }

      # Hardcode the default admin password as requested for a simplified environment.
      # In a production scenario, this should be retrieved from a secret manager.
      # NOTE: The change of this password might require manual deletion of the
      # 'argocd-initial-admin-secret' for it to be recreated.
      configs = {
        secret = {
          argocdServerAdminPassword = bcrypt("$2a$10$rVIyA5x3y4pUfB2PA24wouj9SIymqncZ32dG/mTrn2JzXekm2y14m") # "password"
        }
      }
    })
  ]
  # --- END OF ADDED BLOCK ---

}

# Deploy ArgoCD's "App of Apps".
resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "root"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "HEAD"
        path           = "kubernetes/charts"
        helm = {
          values = local.argocd_app_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}