# 01-infra/locals.tf

locals {
  cluster_base_subdomain = "${var.site_code}.${var.environment}"
  cluster_base_domain    = "${local.cluster_base_subdomain}.${var.domain_name}"
  api_server_fqdn      = "api.${local.cluster_base_domain}"

  # --- DEFINITIVE FIX v3 ---
  # REMOVED the invalid '--kubelet-arg=apparmor-profile=unconfined' which caused the K3s service to crash loop.
  # The Kubelet in this K3s version does not accept this flag.
  # Disabling SELinux is sufficient for the "insecure" requirement.
  k3s_install_args_string = join(" ", [
    "server",
    "--disable=traefik",
    "--disable=servicelb",
    "--flannel-iface=eth0",
    "--datastore-endpoint=http://127.0.0.1:2379",
    "--tls-san=${local.api_server_fqdn}",
    "--tls-san=${var.vps_ip}",
    "--selinux=false"
  ])
}