# ------------------------------------------------------------------------------
# File: cloudflare/main.tf
# ------------------------------------------------------------------------------

locals {
  vault = {
    url   = "https://192.168.15.3:8081"
    mount = "kvv2"
    tls_verify = false
    secrets = [
      {
        name = "cloudflare"
        path = "cloudflare"
        type = "data"
      },
      {
        name = "cloudflare_provider"
        path = "cloudflare"
        type = "ephemeral"
      }
    ]
  }

  config = yamldecode( templatefile("./config.yml", {
    id      = module.vault.data_secrets["cloudflare"].account_id
    zone_id = module.vault.data_secrets["cloudflare"].zone_id
  }))
}

module "vault" {
  source = "github.com/oxdeca/ctlabs-terraform//modules/gcp/vault?ref=main"
  vault  = local.vault
}

module "cloudflare_account_token" {
  source  = "../"
  account = nonsensitive(local.config.account)
}
