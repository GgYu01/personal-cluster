# 02-apps/main.tf (Simplified for Script-based ArgoCD Deployment)

# This Terraform configuration now assumes that ArgoCD has already been installed
# on the cluster by an external script. Its only responsibility is to manage
# the root Application CR.

resource "kubectl_manifest" "root_app" {
  # We still depend on the infra state for provider configuration,
  # but no longer on any helm_release.

  yaml_body = templatefile("${path.module}/root-app-template.yaml", {
    gitops_repo_url = var.gitops_repo_url
  })
}
