# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/functions/main.tf
# Description : functions module
# -----------------------------------------------------------------------------

resource "google_storage_bucket_object" "code" {
  for_each = { for func in var.functions : func.name => func }

  name   = each.value.name
  source = each.value.source
  bucket = each.value.bucket
}

resource "google_cloudfunctions_function" "func" {
  for_each = { for func in var.functions : func.name => func }

  name                  = each.value.name
  description           = each.value.desc
  runtime               = each.value.runtime

  available_memory_mb   = each.value.mem
  source_archive_bucket = each.value.bucket
  source_archive_object = each.value.object
  trigger_http          = try( each.value.http,     false )
  entry_point           = try( each.value.entry,    null  )

  labels                = try( each.value.labels,   null )
  environment_variables = try( each.value.env_vars, null )
}
