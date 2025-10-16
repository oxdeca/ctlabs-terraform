# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/main.tf
# Description : project module
# -----------------------------------------------------------------------------

locals {
  module_defaults = {
    project_type   = "regular"   # regular|host|service
    delete_policy  = "ABANDON"   # PREVENT|ABANDON|DELETE
    create_network = false
    sa_delete      = true
  }
  project_name = try(var.project.name, var.project.id  )
  project_id   = try(var.project.id,   var.project.name)
}

resource "google_project" "project" {
  name                = local.project_name
  project_id          = local.project_id
  billing_account     = var.project.billing
  org_id              = try( var.project.fid, null ) == null ? var.project.oid : null
  folder_id           = try( var.project.oid, null ) == null ? var.project.fid : null
  labels              = try( var.project.labels, null )
  deletion_policy     = try( var.project.delete_policy,  local.module_defaults.delete_policy  )
  auto_create_network = try( var.project.create_network, local.module_defaults.create_network )
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
  count = try( var.project.sa_delete, local.module_defaults.sa_delete ) ? 1 : 0

  project        = var.project.id
  action         = "DELETE"
  restore_policy = "REVERT"

  depends_on     = [google_project.project, google_project_service.compute]
}

resource "google_compute_shared_vpc_host_project" "host_project" {
  count = try( var.project.type, local.module_defaults.project_type ) == "host" ? 1 : 0

  project = var.project.id

  depends_on = [google_project.project, google_project_service.compute]
}

resource "google_compute_shared_vpc_service_project" "service_project" {
  count = try( var.project.type, local.module_defaults.project_type ) == "service" ? 1 : 0

  host_project    = var.project.host_project
  service_project = var.project.id

  depends_on = [google_project.project, google_project_service.compute]
}
