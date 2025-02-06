terraform {
  required_version = ">= 1.3.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
  }
  cloud {
    organization = "ragul_kachiappan_personal"
    workspaces {
      name = "ragulk-cloudflare"
    }
  }
}


provider "cloudflare" {
  api_token = "<YOUR_API_TOKEN>"
}
