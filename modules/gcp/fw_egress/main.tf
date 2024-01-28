# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/fw-egress/main.tf
# Description : fw-egress module
# -----------------------------------------------------------------------------

resource "google_compute_firewall" "egress" {
  for_each = { for rule in var.egress : rule.name => rule }

  direction          = "EGRESS"
  name               = each.value.name
  network            = each.value.net
  destination_ranges = each.value.dst
  priority           = each.value.prio

  dynamic allow {
    for_each = each.value.action  == "allow" ? toset([each.value.action]) : toset([])
    content {
      protocol = each.value.proto
      ports    = (contains(["tcp", "udp", "sctp"], each.value.proto)) ? each.value.ports : []
      //ports    = var.ports
    }
  }

  dynamic deny {
    for_each = each.value.action == "deny" ? toset([each.value.action]) : toset([])
    content {
      protocol = each.value.proto
      ports    = (contains(["tcp", "udp", "sctp"], each.value.proto)) ? each.value.ports : []
    }
  }

  dynamic log_config {
    for_each = each.value.log == true ? toset([each.value.log]) : toset([])
    content {
      metadata = "EXCLUDE_ALL_METADATA"
    }
  }
}