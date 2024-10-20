# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/03_bigquery/gcp/main.tf
# Description : terraform configuration to provision bigquery lab in gcp
# -----------------------------------------------------------------------------

locals { gcpconf = yamldecode( file("./gcp.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml") ) }


module "bq" {
  source = "../modules/gcp/ctlabs"

  project = local.gcpconf.project
  config  = local.config
}

