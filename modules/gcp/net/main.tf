# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/net/main.tf
# Description : net module
# -----------------------------------------------------------------------------

resource "google_compute_network" "net" {
  for_each = { for net in var.networks : net.name => net }

  name                    = each.value.name
  description             = each.value.desc
  auto_create_subnetworks = each.value.subnets
  routing_mode            = each.value.routing_mode
  project                 = var.project.id
}
