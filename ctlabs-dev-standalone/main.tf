# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/ctlabs-dev-standalone/gcp/main.tf
# Description : terraform configuration to provision service project
# -----------------------------------------------------------------------------

import {
  to = module.ctlabs-dev-standalone.google_project.project
  id = "ctlabs-dev-standalone"
}

locals {
  vault = {
    url   = "https://192.168.99.5:8200"
    mount = "kvv2"
    tls_verify = false
    secrets = [{
      name = "ctlabs-dev-standalone"
      path = "dev/ctlabs-dev-standalone"
      type = "data"
    }]
  }
  
  config = yamldecode( templatefile("./config.yml", {
    billing  = module.vault.data_secrets["ctlabs-dev-standalone"].billing
    folder   = module.vault.data_secrets["ctlabs-dev-standalone"].folder
    ssh_keys = module.vault.data_secrets["ctlabs-dev-standalone"].ssh_keys
  }))
}

module "ctlabs-dev-standalone" {
  #source = "../../modules/gcp/project"
  source = "github.com/oxdeca/ctlabs-terraform/modules/gcp/project?ref=main"
  project  = nonsensitive(local.config.project)
}

module "network" {
  source  = "../modules/gcp/net"
  project = local.config.project
  network = nonsensitive(local.config.networks)
  depends_on = [module.ctlabs-dev-standalone]
}

module "firewall" {
  source   = "../modules/gcp/firewall"
  project  = local.config.project
  firewall = nonsensitive(local.config.firewall)
  depends_on = [module.network]
}

module "vm" {
  source  = "../modules/gcp/vm"
  project = local.config.project
  vms     = nonsensitive(local.config.vms)
  depends_on = [module.network]
}

module "vault" {
  #source = "../modules/gcp/vault"
  source = "github.com/oxdeca/ctlabs-terraform/modules/gcp/vault?ref=dev"
  vault  = local.vault
}
