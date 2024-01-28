# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/subnet/main.tf
# Description : subnet module
# -----------------------------------------------------------------------------


resource "google_compute_subnetwork" "sub" {
  for_each = { for sub in var.subnets : sub.name => sub }

  network       = each.value.net
  name          = each.value.name
  ip_cidr_range = each.value.cidr
  region        = var.project.region
}

