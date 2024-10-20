# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/05_host-vpc/gcp/main.tf
# Description : terraform configuration to provision host-vpc
# -----------------------------------------------------------------------------

locals { gcpconf = yamldecode( file("./gcp.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml") ) }


module "secrets" {
  source = "../../modules/gcp/ctlabs"

  project = local.gcpconf.project
  config  = local.config
}
