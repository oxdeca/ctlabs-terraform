# ------------------------------------------------------------------------------
# File: provider.tf
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

provider "cloudflare" {
  api_token = module.vault.secrets["cloudflare_provider"].account_token
}
