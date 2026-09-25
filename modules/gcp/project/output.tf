# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/output.tf
# Description : project module
# -----------------------------------------------------------------------------

output "project" {
  value = google_project.project
}

output "service_account" {
  value = google_project_service_accounts.sa
}