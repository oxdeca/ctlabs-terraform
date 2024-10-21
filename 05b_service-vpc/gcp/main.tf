# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/05b_service-vpc/gcp/main.tf
# Description : terraform configuration to provision service project
# -----------------------------------------------------------------------------

locals { gcpconf = yamldecode( file("./gcp.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml") ) }


module "secrets" {
  source = "../../modules/gcp/ctlabs"

  project = local.gcpconf.project
  config  = local.config
}

