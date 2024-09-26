# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/04_secrets/gcp/main.tf
# Description : terraform configuration to provision secrets lab
# -----------------------------------------------------------------------------

locals { gcpconf = yamldecode( file("../../gcp.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml") ) }


module "secrets" {
  source = "../../modules/gcp/ctlabs"

  project = local.gcpconf.project
  config  = local.config
}

