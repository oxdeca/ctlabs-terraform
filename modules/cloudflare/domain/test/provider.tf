# ------------------------------------------------------------------------------
# File: ctlabs-terraform/modules/cloudflare/domain/test/provider.tf
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

provider "cloudflare" {
  api_token = module.vault.secrets["p_cloudflare"].account_token
}
