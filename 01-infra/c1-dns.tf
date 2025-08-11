# 01-infra/c1-dns.tf

# --- Data Source: Query for existing wildcard DNS record ---
# This is used by the deployment script to check if the record already exists.
# We use 'cloudflare_records' (plural) as it supports filtering by name and type.
data "cloudflare_records" "wildcard_check" {
  zone_id = data.cloudflare_zones.selected.zones[0].id
  filter {
    name = "*.${local.cluster_base_subdomain}"
    type = "A"
  }
}

# --- Resource: Create wildcard DNS record ---
# This resource is ONLY targeted by the deployment script if the data source above returns no results.
resource "cloudflare_dns_record" "cluster_wildcard" {
  zone_id = data.cloudflare_zones.selected.zones[0].id
  name    = "*.${local.cluster_base_subdomain}"
  value   = var.vps_ip # 'value' is the correct argument name, not 'content'
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Terraform-managed wildcard for personal cluster"
}

# --- Data Source: Get Zone Info (Unchanged but critical) ---
data "cloudflare_zones" "selected" {
  filter {
    name = var.domain_name
  }
}
