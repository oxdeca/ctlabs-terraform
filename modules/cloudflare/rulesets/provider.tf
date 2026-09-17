# -----------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/rulesets/provider.tf
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = ">= 5.16.0"
    }
  }
}
