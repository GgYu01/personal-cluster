# bootstrap/c1-dns.tf

# --- Data Source: Get Zone ID ---
# Use the 'cloudflare_zones' (plural) data source and filter by the 'name'
# attribute directly at the top level, as per the v5.8.2 documentation.
data "cloudflare_zones" "selected" {
  name = var.domain_name
}

# --- Resource: Create DNS Record ---
resource "cloudflare_dns_record" "cluster_wildcard" {
  # CRITICAL CHANGE: This resource is now conditional.
  # It will only be created if a Cloudflare zone is found AND var.manage_dns_record is true.
  # The '&&' operator ensures both conditions must be met.
  count = length(data.cloudflare_zones.selected.result) > 0 && var.manage_dns_record ? 1 : 0

  # The zone_id is retrieved from the 'id' of the first element in the
  # 'result' list returned by the data source.
  # The 'try' function handles the case where no zones are found, preventing an error.
  zone_id = try(data.cloudflare_zones.selected.result[0].id, null)

  # The name of the DNS record, derived from local variables.
  name = "*.${local.cluster_base_subdomain}"

  # The 'content' argument holds the IP address.
  content = var.vps_ip

  # The type of the DNS record.
  type = "A"

  # Time To Live for the record in seconds.
  ttl = 300

  # Ensure the record is DNS Only (not proxied).
  proxied = false

  # A descriptive comment for the record.
  comment = "Terraform-managed wildcard for personal cluster"
}
