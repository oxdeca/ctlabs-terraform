# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/main.tf
# Description : project module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "host_vpc"      = false,
    "sa_delete"     = true,
    "delete_policy" = "DELETE",
  }
}

resource "google_project" "prj" {
  name            = var.project.name
  project_id      = var.project.id
  org_id          = var.project.oid
  #folder_id      = var.project.folder
  billing_account = var.project.billing
  labels          = var.project.labels
  deletion_policy = try( var.project.delete_policy, local.defaults.delete_policy )
}

resource "google_project_service" "compute" {
  project  = var.project.id
  service  = "compute.googleapis.com"

  timeouts {
    create = "30m"
    delete = "30m"
  }

  depends_on = [google_project.prj]
}

resource "google_project_default_service_accounts" "sa" {
  count = try( var.project.sa_delete, local.defaults.sa_delete ) ? 1 : 0

  project        = var.project.id
  action         = "DELETE"
  restore_policy = "REVERT"

  depends_on     = [google_project.prj, google_project_service.compute]
}

resource "google_compute_shared_vpc_host_project" "host_vpc" {
  count = try( var.project.host_vpc, local.defaults.host_vpc ) ? 1 : 0

  project = var.project.id
  
  depends_on = [google_project.prj, google_project_service.compute]
}

resource "google_compute_shared_vpc_service_project" "service_project" {
  count = try( var.project.host_project, null ) != null ? 1 : 0

  host_project    = var.project.host_project
  service_project = var.project.id

  depends_on = [google_project.prj, google_project_service.compute]
}