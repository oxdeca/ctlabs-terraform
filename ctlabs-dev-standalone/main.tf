# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/ctlabs-prj-2025101601/gcp/main.tf
# Description : terraform configuration to provision service project
# -----------------------------------------------------------------------------

locals {
  project {
    name    = "ctlabs-dev-standalone"
    billing = module.secrets.data_secrets["ctlabs-dev-standalone"].billing
    folder  = module.secrets.data_secrets["ctlabs-dev-standalone"].folder
  }
  config  = yamldecode(templatefile("./config.yml", {
    project = local.project.name
    folder  = local.project.folder
    billing = local.project.billing
  }))
}

module "ctlabs-dev-standalone" {
  #source = "../../modules/gcp/ctlabs"
  source = "github.com/oxdeca/ctlabs-terraform/modules/gcp/project?ref=main"
  project  = local.config.project
}

module "network" {
  source  = "../modules/gcp/net"
  project = local.config.project
  network = local.config.networks
  depends_on = [module.ctlabs-dev-standalone]
}

module "firewall" {
  source   = "../modules/gcp/firewall"
  project  = local.config.project
  firewall = local.config.firewall
  depends_on = [module.network]
}

module "vm" {
  source  = "../modules/gcp/vm"
  project = local.config.project
  vms     = local.config.vms
  depends_on = [module.network]
}

module "vault" {
  source = "../modules/gcp/vault"
  vault  = local.config.vault
}
