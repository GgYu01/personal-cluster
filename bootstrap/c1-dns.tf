# bootstrap/c1-dns.tf
resource "cloudflare_record" "wildcard" {
  zone_id = data.cloudflare_zones.selected.zones[0].id
  name    = "*"
  value   = var.vps_ip
  type    = "A"
  proxied = false # DNS Only
  ttl     = 300
}

resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zones.selected.zones[0].id
  name    = "@" # Represents the root domain
  value   = var.vps_ip
  type    = "A"
  proxied = false # DNS Only
  ttl     = 300
}

data "cloudflare_zones" "selected" {
  filter {
    name = var.domain_name
  }
}