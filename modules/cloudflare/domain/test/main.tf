# ------------------------------------------------------------------------------
# File: ctlabs-terraform/modules/cloudflare/domain/test/main.tf
# ------------------------------------------------------------------------------

locals {
  vault = {
    url   = "https://192.168.99.3:8200"
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

module "domain" {
  source  = "../"
  domain  = local.config.domain
}

module "dns" {
  source = "../../dns"
  domain = {
    id           = module.domain.id
    name         = local.config.domain.name
    parent       = try(local.config.domain.parent, null)
    name_servers = module.domain.name_servers
    records      = try(local.config.dns, [])
  }
}

module "rulesets" {
  source   = "../../rulesets"
  zone_id  = module.domain.id
  rulesets = local.config.rulesets
}
