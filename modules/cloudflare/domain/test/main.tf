# ------------------------------------------------------------------------------
# File: ctlabs-terraform/modules/cloudflare/domain/test/main.tf
# ------------------------------------------------------------------------------

locals {
  # account_id/zone_id are non-secret and injected by conftest.py (TF_VAR_*).
  # The Cloudflare API token is consumed ephemerally in provider.tf.
  config = yamldecode( templatefile("./config.yml", {
    id      = var.cloudflare_account_id
    zone_id = var.cloudflare_zone_id
  }))
}

module "domain" {
  source  = "../"
  account = { id = var.cloudflare_account_id }
  domain  = local.config.domain
}

module "dns" {
  source  = "../../dns"
  account = { id = var.cloudflare_account_id }
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
  account  = { id = var.cloudflare_account_id }
  zone_id  = module.domain.id
  rulesets = local.config.rulesets
}
