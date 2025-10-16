# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/05_host-vpc/gcp/main.tf
# Description : terraform configuration to provision host-vpc
# -----------------------------------------------------------------------------

locals { gcpconf = yamldecode( file("./gcp.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml") ) }


module "project" {
  #source = "../../modules/gcp/ctlabs"
  source = "github.com/oxdeca/ctlabs-terraform?ref=dev/modules/gcp/ctlabs"

  netbox = []
  project = local.gcpconf.project
  config  = local.config
}

