# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/net/main.tf
# Description : net module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "subnets" = false,
  }
}

resource "google_compute_network" "net" {
  for_each = { for net in var.nets : net.name => net }

  name                    = each.value.name
  auto_create_subnetworks = try( each.value.subnets, local.defaults.subnets )
}
