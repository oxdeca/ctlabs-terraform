# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/test/main.tf
# License : MIT
# -----------------------------------------------------------------------------

locals { config = yamldecode( file("./config.yml") ) }

module "vault" {
  source = "../"
  #source = "github.com/oxdeca/ctlabs-terraform?ref=dev/modules/gcp/vault"

  vault = local.config.vault
}
