# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vaiwb/main.tf
# Description : vertex-ai workbench module
# -----------------------------------------------------------------------------

locals {
  module_defaults = {
    roles     = toset( [ "monitoring.metricWriter", "aiplatform.user", "serviceusage.serviceUsageConsumer", "notebooks.viewer" ] )
    type      = "n2d-standard-2"
    sa_prefix = "vaiwb-"
    labels    = try( var.project.labels, {} )
    fim       = true
    secboot   = true
    vtpm      = true
    disks     = {
      boot = {
        type = "PD_BALANCED"
        size = 150
      }
      data = {
        type = "PD_BALANCED"
        size = 50
      }
    }
    nics = [
      {
        network   = local.network
        subnet    = local.subnet
        nic_type = "GVNIC"
      }
    ]
  }
  network = "projects/${var.project.vpc}/global/networks/${var.project.net}"
  subnet  = "projects/${var.project.vpc}/regions/${var.project.region}/subnetworks/${var.project.sub}"
  disks   = flatten( [ for wb in var.wbs : [ for dk, dv in try(wb.disks, {}) : merge({ wb_id = wb.name, disk_id = dk } , dv) if !startswith(dk, "boot") ] ] )
}


# ---
#
# If SHARED-VPC is used:
#   we have to make sure the service identity of the service projects
#   have access to the subnet in the host project
#

resource "google_project_service_identity" "notebooks_api" {
  provider = google-beta
  project  = var.project.id
  service  = "notebooks.googleapis.com"
}

resource "google_project_iam_member" "notebook_api_sa" {
  project = try( var.project.vpc, var.project.id )
  role    = "roles/compute.networkUser"
  member  = google_project_service_identity.notebooks_api.member
}

#
# ---

resource "google_service_account" "sa" {
  for_each = { for wb in var.wbs : wb.name => wb }

  project      = var.project.id
  account_id   = "${local.module_defaults.sa_prefix}${each.value.name}"
  display_name = try( each.value.name, null )
  description  = try( each.value.desc, null )

  depends_on   = [google_project_iam_member.notebook_api_sa]
}

resource "google_project_iam_member" "iam" {
  for_each = { for wbrole in flatten([ for wb in var.wbs : [ for role in try( wb.roles, local.module_defaults.roles ) : { key = "${wb.name}-${role}", wb_id = wb.name, role = role } ] ] ) : wbrole.key => wbrole }

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
  location                 = try( each.value.location, var.project.zone, var.project.region )
  machine_type             = try( each.value.type,     local.module_defaults.type     )
  labels                   = try( each.value.labels,   local.module_defaults.labels )
  tags                     = try( each.value.tags,     [] )

  service_accounts         = [ { email = try( each.value.sa,  google_service_account.sa[each.key].email ) } ]
  boot_disk_type           = try( each.value.disks.boot.type, local.module_defaults.disks.boot.type )
  boot_disk_size_gb        = try( each.value.disks.boot.size, local.module_defaults.disks.boot.size )
  data_disks               = local.disks
  network_interfaces       = try( each.value.nics, local.module_defaults.nics )
  shielded_instance_config = {
    enable_integrity_monitoring = try( each.value.fim,     local.module_defaults.fim )
    enable_secure_boot          = try( each.value.secboot, local.module_defaults.secboot)
    enablt_vtpm                 = try( each.value.vtpm,    local.module_defaults.vtpm )
  }

  depends_on = [google_service_account.sa, google_project_iam_member.notebook_api_sa]
}
