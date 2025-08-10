# bootstrap/c1-dns.tf

# --- Data Source: Get Zone ID ---
# CORRECTED SYNTAX for cloudflare provider v5.x
# The 'filter' block is removed, and the filter attribute ('name') is at the top level.
data "cloudflare_zones" "selected" {
  name = var.domain_name
}

# --- Resource: Create DNS Record ---
# This resource is managed externally by the deployment script.
# Terraform is only called to apply this target if the script deems it necessary.
resource "cloudflare_dns_record" "cluster_wildcard" {
  # The zone_id is now retrieved from the 'result' attribute of the data source.
  zone_id = try(data.cloudflare_zones.selected.result[0].id, null)
  name    = "*.${local.cluster_base_subdomain}"
  content = var.vps_ip
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Terraform-managed wildcard for personal cluster"
}
