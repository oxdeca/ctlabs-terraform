# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/storage/main.tf
# Description : storage module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "services" = [
      "storage-component.googleapis.com",
    ]
    "class"     = "STANDARD",
    "access"    = "inherited",
    "retention" = false,
    "destroy"   = true,
    "labels"    = {
      "ctlabs_created" = true
    }
  }
}

resource "google_project_service" "services" {
  for_each = toset(local.defaults.services)

  project = var.project.id
  service = each.key
}

resource "google_storage_bucket" "bucket" {
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  name                     = "${var.project.id}--${each.value.name}"
  location                 = each.value.location
  project                  = var.project.id
  labels                   = merge( try(each.value.labels, {} ), local.defaults.labels )
  force_destroy            = try( each.value.destroy,   local.defaults.destroy   )
  storage_class            = try( each.value.class,     local.defaults.class     )
  enable_object_retention  = try( each.value.retention, local.defaults.retention )
  public_access_prevention = try( each.value.access,    local.defaults.access    )

  depends_on = [google_project_service.services]
}

#resource "google_storage_bucket_iam_binding" "iam" {
#  for_each = { for binding in var.buckets[google_storage_bucket.bucket.name].bindings : binding.role => binding }
#
#  bucket     = each.value.name
#  role       = each.value.role
#  members    = each.value.members
#
#  depends_on = [google_storage_bucket.bucket]
#}
