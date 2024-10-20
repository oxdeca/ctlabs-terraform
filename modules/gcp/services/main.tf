# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/services/main.tf
# Description : services module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "disable_dependent" = true,
  }
}

resource "google_project_service" "services" {
  for_each = toset(var.services)

  project  = var.project.id
  service  = each.key
  disable_dependent_service = try( local.defaults.disable_dependent )

  timeouts {
    create = "30m"
    delete = "30m"
  }
}
