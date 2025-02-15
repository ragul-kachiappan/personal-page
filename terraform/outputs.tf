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

# Pages Project outputs
output "pages_project" {
  description = "Details of the Cloudflare Pages project"
  value = {
    name              = cloudflare_pages_project.personal_page_project.name
    production_branch = cloudflare_pages_project.personal_page_project.production_branch
    created_on        = cloudflare_pages_project.personal_page_project.created_on
    subdomain         = cloudflare_pages_project.personal_page_project.subdomain
  }
  sensitive = false
}

output "pages_project_build_config" {
  description = "Build configuration for the Pages project"
  value = {
    build_command   = cloudflare_pages_project.personal_page_project.build_config[0].build_command
    destination_dir = cloudflare_pages_project.personal_page_project.build_config[0].destination_dir
    root_dir        = cloudflare_pages_project.personal_page_project.build_config[0].root_dir
  }
  sensitive = false
}

output "pages_deployment_configs" {
  description = "Deployment configurations for the Pages project"
  value = {
    preview = {
      env_vars  = cloudflare_pages_project.personal_page_project.deployment_configs[0].preview[0].environment_variables
      fail_open = cloudflare_pages_project.personal_page_project.deployment_configs[0].preview[0].fail_open
    }
    production = {
      env_vars  = cloudflare_pages_project.personal_page_project.deployment_configs[0].production[0].environment_variables
      fail_open = cloudflare_pages_project.personal_page_project.deployment_configs[0].production[0].fail_open
    }
  }
  sensitive = false
}
