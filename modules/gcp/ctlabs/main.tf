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

  services = try( var.config.services, [] )
  project  = try( var.project, [] )
}


# -------------------------------------------------------------------------------------------

#
# IAM
#
module "iam" {
  source = "../iam"

  project  = try( var.project, [] )
  roles    = tye( var.config.iam_roles, [] )
  bindings = try( var.config.iam_bindings, [] )
}

# -------------------------------------------------------------------------------------------

#
# Service Accounts
#
module "service_account" {
  source = "../service_account"

  service_accounts = try( var.config.service_accounts, [] )
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

  nets       = try( var.config.network, [] )
  depends_on = [module.services]
}

module "subnet" {
  source     = "../subnet"

  project    = try( var.project, [] )
  subnets    = try( var.config.subnet, [] )
  depends_on = [module.net]
}

# -------------------------------------------------------------------------------------------

#
# FIREWALL
#

module "firewall" {
  source     = "../firewall"

  firewall   = try( var.config.firewall, [] )
  depends_on = [module.net]
}

# -------------------------------------------------------------------------------------------

#
# VM's
#

module "vm" {
  source     = "../vm"

  project    = try( var.project, [] )
  vms        = try( var.config.vms, [] )
  depends_on = [module.net, module.subnet]
}

# -------------------------------------------------------------------------------------------

#
# Storage
#

module "buckets" {
  source = "../buckets"

  buckets = try( var.config.buckets, [] )
}

# -------------------------------------------------------------------------------------------

#
# Functions
#

module "functions" {
  source = "../functions"

  functions  = try( var.config.functions, [] )
  depends_on = [module.buckets, module.services]
}

# -------------------------------------------------------------------------------------------

#
# BigQuery
#

module "bigquery" {
  source = "../bigquery"

  project    = try( var.project, [] )
  bigquery   = try( var.config.bigquery, [] )

  depends_on = [module.services]
}

