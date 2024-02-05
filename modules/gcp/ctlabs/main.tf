# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/main.tf
# Description : terraform configuration to provision a lpic2-lab-VM in GCP
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------

#
# PROJECT
# 

provider "google" {
  project = try( var.project.id )
  region  = try( var.project.region )
  zone    = try( var.project.zone )
}

provider "google-beta" {
  project = try( var.project.id )
  region  = try( var.project.region )
  zone    = try( var.project.zone )
}

# -------------------------------------------------------------------------------------------

#
# NETWORKS
#

module "net" {
  source = "../net"

  nets   = var.config.network
}

module "subnet" {
  source     = "../subnet"

  project    = var.project
  subnets    = var.config.subnet
  depends_on = [module.net]
}

# -------------------------------------------------------------------------------------------

#
# FIREWALL
#

module "fw_ingress" {
  source     = "../fw_ingress"

  ingress    = var.config.firewall.ingress
  depends_on = [module.net]
}

module "fw_egress" {
  source     = "../fw_egress"

  egress     = var.config.firewall.egress
  depends_on = [module.net]
}

# -------------------------------------------------------------------------------------------

#
# VM's
#

module "vm" {
  source     = "../vm"

  project    = var.project
  vms        = var.config.vms
  depends_on = [module.subnet]
}

