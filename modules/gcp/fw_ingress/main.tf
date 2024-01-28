# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/fw-ingress/main.tf
# Description : fw-ingress module
# -----------------------------------------------------------------------------

resource "google_compute_firewall" "ingress" {
  for_each = { for rule in var.ingress : rule.name => rule }

  direction     = "INGRESS"
  name          = each.value.name
  network       = each.value.net
  source_ranges = each.value.src
  priority      = each.value.prio

  dynamic allow {
    for_each = each.value.action == "allow" ? toset([each.value.action]) : toset([])
    content {
      protocol = each.value.proto
      ports    = (contains(["tcp", "udp", "sctp"], each.value.proto)) ? each.value.ports : []
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