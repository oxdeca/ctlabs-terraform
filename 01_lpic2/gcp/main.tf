# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/lpic2/gcp/main.tf
# Description : terraform configuration to provision lab lpic2 in GCP
# -----------------------------------------------------------------------------

locals { gcpconf = yamldecode( file("./gcp.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml") ) }


module "lpic2" {
  source = "../../modules/gcp/ctlabs"

  project = local.gcpconf.project
  config  = local.config
}

