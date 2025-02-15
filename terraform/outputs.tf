# DNS Record details for ragulk.com
output "root_domain_record" {
  description = "Details of the root domain DNS record"
  value = {
    name    = cloudflare_record.root_domain.name
    type    = cloudflare_record.root_domain.type
    proxied = cloudflare_record.root_domain.proxied
    ttl     = cloudflare_record.root_domain.ttl
  }
  sensitive = false
}

# DNS Record details for www subdomain
output "www_subdomain_record" {
  description = "Details of the www subdomain DNS record"
  value = {
    name    = cloudflare_record.www.name
    type    = cloudflare_record.www.type
    proxied = cloudflare_record.www.proxied
    ttl     = cloudflare_record.www.ttl
  }
  sensitive = false
}

# Record IDs (useful for reference)
output "record_ids" {
  description = "IDs of created DNS records"
  value = {
    root_domain = cloudflare_record.root_domain.id
    www         = cloudflare_record.www.id
  }
  sensitive = false
}

output "record_contents" {
  description = "Content of DNS records"
  value = {
    root_domain = cloudflare_record.root_domain.content
    www         = cloudflare_record.www.content
  }
  sensitive = true
}
