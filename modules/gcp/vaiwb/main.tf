# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vaiwb/main.tf
# Description : vertex-ai workbench module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    roles     = toset( [ "monitoring.metricWriter", "aiplatform.user", "serviceusage.serviceUsageConsumer", "notebooks.viewer" ] )
    location  = "us-east1-c"
    type      = "e2-standard-2"
    sa_prefix = "vaiwb-"
    disks     = [
      {
        disk_type    = "PD_BALANCED"
        disk_size_gb = 50
      }
    ]
    shield_conf = {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
      enable_vtpm                 = true
    }
    nics = [
      {
        network  = ""
        subnet   = ""
        nic_type = "GVNIC"
      }
    ]
  }
}

# ---
#
# If we are using a shared vpc we have to make sure the service identity of the service projects
# have access to the subnet we want to use
#

resource "google_project_service_identity" "notebooks_api" {
  provider = google-beta
  project  = var.project.id
  service  = "notebooks.googleapis.com"
}

resource "google_project_iam_member" "notebook_api_sa" {
  project = var.project.shared_vpc
  role    = "roles/compute.networkUser"
  member  = google_project_service_identity.notebooks_api.member
}

#
# ---

resource "google_service_account" "sa" {
  for_each = { for wb in var.wbs : wb.name => wb }

  account_id   = "${local.defaults.sa_prefix}${each.value.name}"
  display_name = try( each.value.name, null )
  description  = try( each.value.desc, null )

  depends_on   = [google_project_iam_member.notebook_api_sa]
}

resource "google_project_iam_member" "iam" {
  for_each = { for pair in flatten([ for wb in var.wbs : [ for role in try( wb.roles, local.defaults.roles ) : { key = "${wb.name}-${role}", wb_id = wb.name, role = role } ] ] ) : pair.key => pair }

  project = var.project.id
  role    = "roles/${each.value.role}"
  member  = "serviceAccount:${google_service_account.sa[each.value.wb_id].email}"

  depends_on = [google_service_account.sa]
}

module "vertex_ai_workbench" {
  source   = "GoogleCloudPlatform/vertex-ai/google//modules/workbench"
  version  = "~> 0.1"
  for_each = { for wb in var.wbs : wb.name => wb }

  name                     = each.value.name
  project_id               = var.project.id
  location                 = try( each.value.location, local.defaults.location )
  machine_type             = try( each.value.type,     local.defaults.type     )
  tags                     = try( each.value.tags,   [] )
  labels                   = try( each.value.labels, {} )

  service_accounts         = [ { email = try( each.value.sa,  google_service_account.sa[each.key].email ) } ]
  data_disks               = try( each.value.disks,       local.defaults.disks )
  shielded_instance_config = try( each.value.shield_conf, local.defaults.shield_conf )

  network_interfaces       = try( each.value.nics, local.defaults.nics )

  depends_on               = [google_service_account.sa, google_project_iam_member.notebook_api_sa]
}
