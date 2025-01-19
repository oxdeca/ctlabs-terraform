# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/functions/main.tf
# Description : functions module
# -----------------------------------------------------------------------------

# uses bucket naming convention: "${var.project.id}--${each.value.bucket}"

locals {
  defaults = {
    sa_prefix  = "crf-",
    sa_postfix = "@${var.project.id}.iam.gserviceaccount.com",
    bindings = [
      { 
        role    = "roles/storage.objectViewer",
        members = []
      }
    ]
  }
}

resource "google_service_account" "sa" {
  for_each = { for func in var.functions : func.name => func }

  account_id   = "${local.defaults.sa_prefix}${replace(each.value.name, "_", "-")}"
  display_name = try( each.value.name, null )
  description  = try( each.value.desc, null )
}

resource "google_project_iam_binding" "binding" {
  for_each = { for binding in local.defaults.bindings : binding.role => binding }

  project    = var.project.id
  role       = "projects/${var.project.id}/roles/${each.value.role}"
  members    = [ for member in each.value.members : "${member}@${var.project.id}.iam.gserviceaccount.com" ]
  depends_on = [google_project_iam_custom_role.role]
}

resource "google_storage_bucket_object" "code" {
  for_each = { for func in var.functions : func.name => func }

  name   = each.value.name
  source = each.value.source
  bucket = "${var.project.id}--${each.value.bucket}"

  depends_on = [google_service_account.sa]
}

resource "google_cloudfunctions_function" "func" {
  for_each = { for func in var.functions : func.name => func }

  name                  = each.value.name
  description           = each.value.desc
  runtime               = each.value.runtime
  service_account_email = "${local.defaults.sa_prefix}${replace(each.value.name, "_", "-")}${local.defaults.sa_postfix}"
  build_service_account = "projects/${var.project.id}/serviceAccounts/${local.defaults.sa_prefix}${replace(each.value.name, "_", "-")}${local.defaults.sa_postfix}"

  available_memory_mb   = each.value.mem
  source_archive_bucket = "${var.project.id}--${each.value.bucket}"
  source_archive_object = each.value.object
  trigger_http          = try( each.value.http,     false )
  entry_point           = try( each.value.entry,    null  )

  labels                = try( each.value.labels,   null )
  environment_variables = try( each.value.env_vars, null )

  depends_on            = [google_storage_bucket_object.code, google_service_account.sa]
}
