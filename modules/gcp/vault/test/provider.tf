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
  server_url           = "https://netbox.engi.oanda.com:8081"
  api_token            = module.vault.secrets["netbox"].api_token
  allow_insecure_https = true
}
