# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/main.tf
# Description : project module
# -----------------------------------------------------------------------------

locals {
  project_name = coalesce(var.project.name, var.project.id)
  org_id       = try( var.project.fid, null ) == null ? var.project.oid : null
  folder_id    = try( var.project.oid, null ) == null ? var.project.fid : null
}

resource "google_project" "project" {
  name                = local.project_name
  project_id          = var.project.id
  billing_account     = var.project.bilact
  org_id              = local.org_id
  folder_id           = local.folder_id
  labels              = var.project.labels
  deletion_policy     = var.project.policy
  auto_create_network = false  # try( var.project.create_network, local.module_defaults.create_network )
}

resource "google_project_service" "compute" {
  project  = var.project.id
  service  = "compute.googleapis.com"

  timeouts {
    create = "30m"
    delete = "30m"
  }

  depends_on = [google_project.project]
}

resource "google_project_default_service_accounts" "sa" {
  project        = var.project.id
  action         = "DELETE"
  restore_policy = "REVERT"

  depends_on     = [google_project.project, google_project_service.compute]
}

resource "google_compute_shared_vpc_host_project" "host_project" {
  count = var.project.type == "host" ? 1 : 0

  project = var.project.id

  depends_on = [google_project.project, google_project_service.compute]
}

resource "google_compute_shared_vpc_service_project" "service_project" {
  count = var.project.type == "service" ? 1 : 0

  host_project    = var.project.host_vpc
  service_project = var.project.id

  depends_on = [google_project.project, google_project_service.compute]
}
