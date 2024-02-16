# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/vm/main.tf
# Description : terraform configuration to provision a lpic2-lab-VM in AWS
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------

#
# PROJECT
# 
provider "aws" {
  profile = var.project.profile
  region  = var.project.region
}

# -------------------------------------------------------------------------------------------

#
# NETWORKS
#
module "networks" {
  source    = "../networks"

  networks  = var.config.networks
}

module "subnets" {
  source     = "../subnets"

  project    = var.project
  subnets    = var.config.subnets
  depends_on = [module.networks]
}

# -------------------------------------------------------------------------------------------

#
# FIREWALL
#

module "fw_ingress" {
  source     = "../fw_ingress"

  ingress    = var.config.firewall.ingress
  networks   = var.config.networks
  depends_on = [module.networks]
}

module "fw_egress" {
  source     = "../fw_egress"

  egress     = var.config.firewall.egress
  networks   = var.config.networks
  depends_on = [module.networks]
}

# -------------------------------------------------------------------------------------------

#
# VM's
#
module "vms" {
  source     = "../vms"

  vms        = var.config.vms
  ssh        = var.ssh
  depends_on = [module.subnets]
}
