# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/dns/main.tf
# Description : dns module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "zone" = {
      "visibility" = "private",
    },
    "rr" = {
      "type" = "A",
      "ttl"  = 86400,
    },
  }
}

resource "google_dns_managed_zone" "zone" {
  for_each = { for zk, zv in var.dns : zk => zv }

  name        = each.key
  dns_name    = each.value.domain
  description = each.value.desc
  labels      = each.value.labels
}

