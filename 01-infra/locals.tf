# bootstrap/locals.tf

locals {
  # 基础子域，例如 "core01.prod"
  cluster_base_subdomain = "${var.site_code}.${var.environment}"

  # 完整的集群基础域名，例如 "core01.prod.gglohh.top"
  cluster_base_domain = "${local.cluster_base_subdomain}.${var.domain_name}"

  # API Server的FQDN
  api_server_fqdn = "api.${local.cluster_base_domain}"

}