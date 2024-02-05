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
# VMs
#
module "vms" {
  source     = "../vms"

  vms        = var.config.vms
  ssh        = var.ssh
  depends_on = [module.subnets]
}
