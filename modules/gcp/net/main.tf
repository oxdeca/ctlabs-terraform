# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/net/main.tf
# Description : net module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "subnets" = false,
  }
  subnets = [ for netk, netv in nets : [ for subnet in ] ]
}

resource "google_compute_network" "net" {
  for_each = { for net in var.nets : net.name => net }

  name                    = each.value.name
  auto_create_subnetworks = local.defaults.subnets
}

resource "google_compute_subnetworks" "subnets" {
  for_each = { for subnet in local.subnets }
}
