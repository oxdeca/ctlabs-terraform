# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/subnet/main.tf
# Description : subnet module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "services" = [
      "compute.googleapis.com",
    ]
    "netflow" = {
      "aggregate" = "INTERVAL_10_MIN",
      "sampling"  = 0.5,
      "metadata"  = "INCLUDE_ALL_METADATA",
    }
  }
  subnets = flatten ( [ for netk, netv in var.subnets: [ for sub in netv: merge( { net_id = netk, }, sub ) ] ] )
}

resource "google_project_service" "services" {
  for_each = toset(local.defaults.services)

  project = var.project.id
  service = each.key
}

resource "google_compute_subnetwork" "sub" {
  for_each = { for sub in local.subnets : sub.name => sub }

  network       = each.value.net_id
  name          = each.value.name
  ip_cidr_range = each.value.cidr
  region        = try( each.value.region, var.project.region )

  log_config {
    aggregation_interval = try( each.value.netflow.aggregate, local.defaults.netflow.aggregate )
    flow_sampling        = try( each.value.newflow.sampling,  local.defaults.netflow.sampling  )
    metadata             = try( each.value.netflow.metadata,  local.defaults.netflow.metadata  )
  }
}

