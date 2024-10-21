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

module "project" {
  source  = "../project"

  project = try( merge( var.project, { "labels" = var.config.defaults.labels } ) )
}

# -------------------------------------------------------------------------------------------

#
# Services
#
module "services" {
  source = "../services"

  services = try( var.config.services, [] )
  project  = try( var.project, [] )

  depends_on = [module.project]
}

# -------------------------------------------------------------------------------------------

#
# Service Accounts
#
module "service_account" {
  source = "../service_account"

  service_accounts = try( var.config.service_accounts, [] )

  depends_on = [module.services]
}

# -------------------------------------------------------------------------------------------

#
# IAM
#
module "iam" {
  source = "../iam"

  project  = try( var.project, [] )
  roles    = try( var.config.iam_roles, [] )
  bindings = try( var.config.iam_bindings, [] )

  depends_on = [module.services, module.service_account]
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

  nets = try( var.config.network, [] )

  depends_on = [module.project, module.services]
}

module "subnet" {
  source = "../subnet"

  project = try( var.project, [] )
  subnets = try( var.config.subnet, [] )

  depends_on = [module.net]
}

# -------------------------------------------------------------------------------------------

#
# FIREWALL
#

module "firewall" {
  source = "../firewall"

  firewall = try( var.config.firewall, [] )

  depends_on = [module.net]
}

# -------------------------------------------------------------------------------------------

#
# DNS
#

module "dns" {
  source = "../dns"

  project = try( var.project, [] )
  dns     = try( var.config.dns, [] )

  depends_on = [module.net]
}

# -------------------------------------------------------------------------------------------

#
# VM's
#

module "vm" {
  source = "../vm"

  project = try( var.project, [] )
  vms     = try( var.config.vms, [] )

  depends_on = [module.net, module.subnet, module.dns]
}

# -------------------------------------------------------------------------------------------

#
# Storage
#

module "buckets" {
  source = "../buckets"

  project = try( var.project, [] )
  buckets = try( var.config.buckets, [] )

  depends_on = [module.services]
}

# -------------------------------------------------------------------------------------------

#
# Functions
#

module "functions" {
  source = "../functions"

  project   = try( var.project, [] )
  functions = try( var.config.functions, [] )

  depends_on = [module.buckets, module.services]
}

# -------------------------------------------------------------------------------------------

#
# BigQuery
#

module "bigquery" {
  source = "../bigquery"

  project  = try( var.project, [] )
  bigquery = try( var.config.bigquery, [] )

  depends_on = [module.services]
}

