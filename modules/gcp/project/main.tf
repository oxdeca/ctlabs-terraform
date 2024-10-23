# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/main.tf
# Description : project module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "vpc_type"       = "regular",
    "sa_delete"      = true,
    "delete_policy"  = "ABANDON",
    "create_network" = false,
  }
}

resource "google_project" "prj" {
  name                = var.project.name
  project_id          = var.project.id
  org_id              = try( var.project.fid, null ) == null ? var.project.oid : null
  folder_id           = try( var.project.oid, null ) == null ? var.project.fid : null
  billing_account     = var.project.billing
  labels              = var.project.labels
  deletion_policy     = try( var.project.delete_policy, local.defaults.delete_policy )
  auto_create_network = try( var.project.create_network, local.defaults.create_network )
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

resource "google_compute_shared_vpc_host_project" "shared_vpc" {
  count = try( var.project.vpc_type, local.defaults.vpc_type ) == "shared" ? 1 : 0

  project = var.project.id

  depends_on = [google_project.prj, google_project_service.compute]
}

resource "google_compute_shared_vpc_service_project" "service_vpc" {
  count = try( var.project.vpc_type, local.defaults.vpc_type ) == "service" ? 1 : 0

  host_project    = var.project.shared_vpc
  service_project = var.project.id

  depends_on = [google_project.prj, google_project_service.compute]
}
