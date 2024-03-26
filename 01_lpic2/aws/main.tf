# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/lpic2/aws/main.tf
# Description : terraform configuration to provision lab lpic2 in AWS
# -----------------------------------------------------------------------------

locals { awsconf = yamldecode( file("../../aws.conf.yml") ) }
locals { config  = yamldecode( file("./config.yml")       ) }


module "lpic2" {
  source = "../../modules/aws/ctlabs"

  project = local.awsconf.project
  ssh     = local.awsconf.ssh
  config  = local.config
}

