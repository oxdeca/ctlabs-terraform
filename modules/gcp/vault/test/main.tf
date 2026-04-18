# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/test/main.tf
# License : MIT
# -----------------------------------------------------------------------------

locals { config = yamldecode( file("./config.yml") ) }

module "vault" {
  source = "../"
  #source = "github.com/oxdeca/ctlabs-terraform//modules/gcp/vault?ref=dev"

  vault = local.config.vault
}
