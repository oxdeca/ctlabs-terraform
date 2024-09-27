# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/fw-ingress/main.tf
# Description : fw-ingress module
# -----------------------------------------------------------------------------

locals {
  ingress = flatten( [ for netk, netv in var.firewall : [ for rule in netv.ingress: merge( { net_id = netk }, rule ) ] ] )
  egress  = flatten( [ for netk, netv in var.firewall : [ for rule in netv.egress : merge( { net_id = netk }, rule ) ] ] )
  defaults = { "proto": "tcp", "prio": 1000, "log": true, "action" : "allow" }
}

resource "google_compute_firewall" "ingress" {
  for_each = { for rule in local.ingress : rule.name => rule }

  direction     = "INGRESS"
  name          = each.value.name
  network       = each.value.net_id
  source_ranges = each.value.src
  priority      = try( each.value.prio, local.defaults.prio )

  dynamic allow {
    for_each = try( each.value.action, local.defaults.action ) == "allow" ? toset(["allow"]) : toset([])
    content {
      protocol = try( each.value.proto, local.defaults.proto )
      ports    = (contains(["tcp", "udp", "sctp"], try( each.value.proto, local.defaults.proto ) ) ? try( each.value.ports, []) : [])
    }
  }

  dynamic deny {
    for_each = try( each.value.action, local.defaults.action ) == "deny" ? toset(["deny"]) : toset([])
    content {
      protocol = try( each.value.proto, local.defaults.proto )
      ports    = (contains(["tcp", "udp", "sctp"], try( each.value.proto, local.defaults.proto ) ) ? try( each.value.ports, []) : [])
    }
  }

  dynamic log_config {
    for_each = try( each.value.log, local.defaults.log ) == true ? toset([try( each.value.log, local.defaults.log )]) : toset([])
    content {
      metadata = "EXCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_firewall" "egress" {
  for_each = { for rule in local.egress : rule.name => rule }

  direction          = "EGRESS"
  network            = each.value.net_id
  name               = each.value.name
  destination_ranges = each.value.dst
  priority            = try( each.value.prio, local.defaults.prio )

  dynamic allow {
    for_each = try( each.value.action, local.defaults.action )  == "allow" ? toset(["allow"]) : toset([])
    content {
      protocol = try( each.value.proto, local.defaults.proto )
      ports    = (contains(["tcp", "udp", "sctp"], try( each.value.proto, local.defaults.proto ) ) ? try( each.value.ports, []) : [])
    }
  }

  dynamic deny {
    for_each = try( each.value.action, local.defaults.action ) == "deny" ? toset(["deny"]) : toset([])
    content {
      protocol = try( each.value.proto, local.defaults.proto )
      ports    = (contains(["tcp", "udp", "sctp"], try( each.value.proto, local.defaults.proto ) ) ? try( each.value.ports, []) : [])
    }
  }

  dynamic log_config {
    for_each = try( each.value.log, local.defaults.log ) == true ? toset([try( each.value.log, local.defaults.log )]) : toset([])
    content {
      metadata = "EXCLUDE_ALL_METADATA"
    }
  }
}