# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/net/main.tf
# Description : net module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "services" = [
      "compute.googleapis.com",
    ],
    "subnets" = false,
  }
}

resource "google_project_service" "services" {
  for_each = toset(local.defaults.services)

  project = var.project.id
  service = each.key
}

resource "google_compute_network" "net" {
  for_each = { for net in var.nets : net.name => net }

  name                    = each.value.name
  auto_create_subnetworks = try( each.value.subnets, local.defaults.subnets )

  depends_on = [google_project_service.services]
}
