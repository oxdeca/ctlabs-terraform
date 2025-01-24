# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/storage/main.tf
# Description : storage module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "class"     = "STANDARD",   # STANDARD, MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, ARCHIVE, AUTO
    "access"    = "uniform"
    "public"    = false
    "retention" = false,
    "destroy"   = true,
    "labels"    = {
      "ctlabs_created" = true
    }
  }
}

resource "google_storage_bucket" "bucket" {
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  name                        = "${var.project.id}--${each.key}"
  location                    = try( each.value.location, local.defaults.location )
  project                     = var.project.id
  labels                      = merge( try(each.value.labels, {} ), local.defaults.labels )
  force_destroy               = try( each.value.destroy,   local.defaults.destroy   )
  storage_class               = try( each.value.class,     local.defaults.class     ) == "AUTO" ? null : try( each.value.class, local.defaults.class )
  enable_object_retention     = try( each.value.retention, local.defaults.retention )
  public_access_prevention    = try( each.value.public,    local.defaults.public    ) == false     ? true : false
  uniform_bucket_level_access = try( each.value.access,    local.defalts.access     ) == "uniform" ? true : false

  dynamic autoclass {
    for_each = try( each.value.class, local.defaults.class ) == "AUTO" ? toset([1]) : toset([])
    content {
      enabled = true
    }
  }
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
