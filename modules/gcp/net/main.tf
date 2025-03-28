# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/net/main.tf
# Description : net module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    subnets      = false
    routing_mode = "REGIONAL"
    desc         = ""
  }
}

resource "google_compute_network" "net" {
  for_each = { for net in var.nets : net.name => net }

  name                    = each.value.name
  description             = try( each.value.desc,         local.defaults.desc )
  auto_create_subnetworks = try( each.value.subnets,      local.defaults.subnets )
  routing_mode            = try( each.value.routing_mode, local.defaults.routing_mode)
}
