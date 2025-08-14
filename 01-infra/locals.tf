# 01-infra/locals.tf

locals {
  # Base subdomain, e.g., "core01.prod"
  cluster_base_subdomain = "${var.site_code}.${var.environment}"

  # Fully qualified base domain, e.g., "core01.prod.gglohh.top"
  cluster_base_domain = "${local.cluster_base_subdomain}.${var.domain_name}"

  # FQDN for the API Server
  api_server_fqdn = "api.${local.cluster_base_domain}"

  # --- MODIFICATION: Added flags to explicitly disable security modules ---
  # This is the core fix for the "InvalidDiskCapacity" error, which is often
  # caused by AppArmor/SELinux interference preventing Kubelet from stat'ing
  # the filesystem.
  k3s_install_args_string = join(" ", [
    "server",
    "--disable=traefik",
    "--disable=servicelb",
    "--flannel-iface=eth0",
    "--datastore-endpoint=http://127.0.0.1:2379",
    "--tls-san=${local.api_server_fqdn}",
    "--tls-san=${var.vps_ip}",
    "--selinux=false",                # Explicitly disable SELinux integration.
    "--apparmor-profile=unconfined"   # Run containers without AppArmor restrictions.
  ])
}