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
      "ttl"  = 21600,
    },
  }
}

resource "google_dns_managed_zone" "zone" {
  for_each = { for zk, zv in var.dns : zk => zv }

  name        = each.key
  dns_name    = "${each.value.domain}."
  description = try(each.value.desc, null)
  labels      = try(each.value.labels, null)
  visibility  = try(each.value.type, local.defaults.zone.visibility)

  private_visibility_config {
    dynamic networks {
      for_each = toset(each.value.networks)
      content {
        network_url = try("projects/${var.project.id}/global/networks/${networks.value}", null)
      }
    }
  }
}
