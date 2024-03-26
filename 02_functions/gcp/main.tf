# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/02_buckets/gcp/main.tf
# Description : terraform configuration to provision lab 02_buckets in GCP
# -----------------------------------------------------------------------------

locals { gcpconf = yamldecode( file("../../gcp.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml") ) }


module "buckets" {
  source = "../../modules/gcp/ctlabs"

  project = local.gcpconf.project
  config  = local.config
}

