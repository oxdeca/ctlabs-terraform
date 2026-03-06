# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/test/provider.tf
# License : MIT
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
    }
  }
}

provider "netbox" {
  server_url           = module.vault.ephemeral_secrets["netbox"].server_url
  api_token            = module.vault.ephemeral_secrets["netbox"].api_token
  allow_insecure_https = true
}
