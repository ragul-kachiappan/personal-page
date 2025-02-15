variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID"
  sensitive   = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID"
  sensitive   = true
}

variable "cloudflare_email" {
  type        = string
  description = "Cloudflare email"
  sensitive   = true
}

variable "cloudflare_record_content" {
  type        = string
  description = "Cloudflare record content"
  sensitive   = true
}
