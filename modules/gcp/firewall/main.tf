# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/firewall/main.tf
# Description : firewall module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "proto"    = "tcp",
    "prio"     = 1000, 
    "action"   = "allow",
    "log"      = true,
    "metadata" = true,
    "enable"   = true,
  }
  ingress = flatten( [ for netk, netv in var.firewall : [ for rule in netv.ingress: merge( { net_id = netk }, rule ) ] ] )
  egress  = flatten( [ for netk, netv in var.firewall : [ for rule in netv.egress : merge( { net_id = netk }, rule ) ] ] )
}

resource "google_compute_firewall" "ingress" {
  for_each = { for rule in local.ingress : rule.name => rule }

  direction     = "INGRESS"
  project       = try( each.value.project, null)
  name          = each.value.name
  network       = each.value.net_id
  source_ranges = each.value.src
  priority      = try( each.value.prio, local.defaults.prio )
  target_tags   = try( each.value.tags, null )
  description   = try( each.value.desc, null )
  disabled      = try( each.value.enable, local.defaults.enable) == false ? true : false

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
      metadata = try( each.value.metadata, local.defaults.metadata ) == true ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_firewall" "egress" {
  for_each = { for rule in local.egress : rule.name => rule }

  direction          = "EGRESS"
  project            = try( each.value.project, null)
  name               = each.value.name
  network            = each.value.net_id
  destination_ranges = each.value.dst
  priority           = try( each.value.prio, local.defaults.prio )
  target_tags        = try( each.value.tags, null )
  description        = try( each.value.desc, null )
  disabled           = try( each.value.enable, local.defaults.enable) == false ? true : false

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
      metadata = try( each.value.metadata, local.defaults.metadata ) == true ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
    }
  }
}
