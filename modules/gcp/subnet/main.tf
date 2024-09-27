# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/subnet/main.tf
# Description : subnet module
# -----------------------------------------------------------------------------

locals {
  subnets = flatten ( [ for netk, netv in var.subnets: [ for sub in netv: merge( { net_id = netk, }, sub ) ] ] )
}

resource "google_compute_subnetwork" "sub" {
  for_each = { for sub in local.subnets : sub.name => sub }

  network       = each.value.net_id
  name          = each.value.name
  ip_cidr_range = each.value.cidr
  region        = var.project.region
}

