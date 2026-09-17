# ------------------------------------------------------------------------------
# File : ctlabs-terraform/module/cloudflare/dns/provider.tf
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.16"
    }
  }
}
