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

resource "cloudflare_pages_project" "personal_page_project" {
  account_id        = var.cloudflare_account_id
  name              = "personal-page"
  production_branch = "main"

  source {
    type = "github"
    config {
      owner                         = "ragul-kachiappan"
      repo_name                     = "personal-page"
      production_branch             = "main"
      pr_comments_enabled           = true
      deployments_enabled           = true
      production_deployment_enabled = true
      preview_deployment_setting    = "custom"
      preview_branch_includes       = ["preview/*"]
    }
  }

  build_config {
    build_command   = "hugo -b $CF_PAGES_URL"
    destination_dir = "public"
    root_dir        = "src"
  }

  deployment_configs {
    preview {
      environment_variables = {
        HUGO_VERSION = "0.143.0"
      }
      fail_open   = true
      usage_model = "standard"
    }
    production {
      environment_variables = {
        CF_PAGES_URL = "https://ragulk.com"
        HUGO_VERSION = "0.143.0"
      }
      fail_open   = true
      usage_model = "standard"
    }
  }
}
