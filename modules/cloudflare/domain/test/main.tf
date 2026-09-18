# ------------------------------------------------------------------------------
# File: ctlabs-terraform/modules/cloudflare/domain/test/main.tf
#
# Not a reusable module: the stack's configuration lives in config.yml and the
# (non-secret) Cloudflare account id is read from Vault alongside the API token,
# so no input variables are needed.
# ------------------------------------------------------------------------------

data "vault_generic_secret" "cloudflare_meta" {
  # KV v2 path — the provider auto-appends the /data/ segment. Only the
  # (non-secret) account id is used here; the API token itself is ephemeral.
  path = "kvv2/cloudflare"
}

locals {
  cloudflare_account_id = nonsensitive(data.vault_generic_secret.cloudflare_meta.data["account_id"])
  config                = yamldecode(file("./config.yml"))
}

module "domain" {
  source  = "../"
  account = { id = local.cloudflare_account_id }
  domain  = local.config.domain
}

module "dns" {
  source  = "../../dns"
  account = { id = local.cloudflare_account_id }
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
  account  = { id = local.cloudflare_account_id }
  zone_id  = module.domain.id
  rulesets = local.config.rulesets
}
