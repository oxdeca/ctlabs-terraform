# -----------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/account_token/provider.tf
# Desc : required providers and versions
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = ">= 5.16.0"
    }
  }
}
