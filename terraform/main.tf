resource "cloudflare_record" "root_domain" {
  content = var.cloudflare_record_content
  name    = "ragulk.com"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_record" "www" {
  content = var.cloudflare_record_content
  name    = "www"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  zone_id = var.cloudflare_zone_id
}
