# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/functions/main.tf
# Description : functions module
# -----------------------------------------------------------------------------

# uses bucket naming convention: "${var.project.id}--${each.value.bucket}"

locals {
  defaults = {
    "services" = [
      "storage-component.googleapis.com",
      "cloudfunctions.googleapis.com",
      "cloudbuild.googleapis.com",
      "iam.googleapis.com"
    ]
    "sa_prefix" = "crf-",
    "sa_postfix" = "@${var.project.id}.iam.gserviceaccount.com",
  }
}

resource "google_project_service" "services" {
  for_each = toset(local.defaults.services)

  project  = var.project.id
  service  = each.value
}

resource "google_service_account" "sa" {
  for_each = { for func in var.functions : func.name => func }

  account_id   = "${local.defaults.sa_prefix}${replace(each.value.name, "_", "-")}"
  display_name = try( each.value.name, null )
  description  = try( each.value.desc, null )

  depends_on = [google_project_service.services]
}

resource "google_storage_bucket_object" "code" {
  for_each = { for func in var.functions : func.name => func }

  name   = each.value.name
  source = each.value.source
  bucket = "${var.project.id}--${each.value.bucket}"

  depends_on = [google_project_service.services, google_service_account.sa]
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

  depends_on            = [google_project_service.services, google_project_service.services, google_storage_bucket_object.code, google_service_account.sa]
}
