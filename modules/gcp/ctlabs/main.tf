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
# Services
#
module "services" {
  source = "../services"

  services = var.config.services
  project  = var.project
}


# -------------------------------------------------------------------------------------------

#
# Costs
#

#module "costs" {
#  source = "../costs"
#
#  project = var.project
#  vms     = var.config.vms
#}

# -------------------------------------------------------------------------------------------

#
# NETWORKS
#

module "net" {
  source = "../net"

  nets       = var.config.network
  #depends_on = [module.costs]
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
  depends_on = [module.net, module.subnet]
}

# -------------------------------------------------------------------------------------------

#
# Storage
#

module "buckets" {
  source = "../buckets"

  buckets = var.config.buckets
}

# -------------------------------------------------------------------------------------------

#
# Functions
#

module "functions" {
  source = "../functions"

  functions  = var.config.functions
  depends_on = [module.buckets, module.services]
}

# -------------------------------------------------------------------------------------------
