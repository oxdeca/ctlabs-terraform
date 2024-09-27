# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/services/main.tf
# Description : services module
# -----------------------------------------------------------------------------

resource "google_project_service" "services" {
  for_each = toset(var.services)
  project  = var.project.id
  service  = each.key

  timeouts {
    create = "30m"
    delete = "30m"
  }
}
