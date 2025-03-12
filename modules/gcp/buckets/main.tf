# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/storage/main.tf
# Description : storage module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    class          = "STANDARD",   # STANDARD, MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, ARCHIVE, AUTO
    private        = true
    location       = "us-east1"
    retention      = false
    destroy        = true
    versioning     = true
    uniform_access = true
    labels         = {
      ctlabs_created = true
    }
  }
  folders       = flatten( [ for bk, bv in var.buckets : [ for fk, fv in try( bv.folders, {} ) : merge( { folder_id = "${var.project.id}-${bk}/${fk}/", bucket_id = "${var.project.id}-${bk}", folder_name = "${fk}/" }, fv ) ] ] )
  bucket_access = flatten( [ for bk, bv in var.buckets : [ for access in try( bv.access, [] )  : merge( { bucket_id = bk }, access ) ] ] )
  #folder_access = flatten( [ for bk])
}

resource "google_storage_bucket" "bucket" {
  for_each = { for bk, bv in var.buckets : bk => bv }

  name                        = "${var.project.id}-${each.key}"
  location                    = try( each.value.location, local.defaults.location )
  project                     = var.project.id
  labels                      = merge( try(each.value.labels, {} ), local.defaults.labels )
  force_destroy               = try( each.value.destroy,        local.defaults.destroy   )
  storage_class               = try( each.value.class,          local.defaults.class     ) == "AUTO" ? null : try( each.value.class, local.defaults.class )
  enable_object_retention     = try( each.value.retention,      local.defaults.retention )
  public_access_prevention    = try( each.value.private,        local.defaults.private   ) == true ? "enforced" : "inherited"
  uniform_bucket_level_access = try( each.value.uniform_access, local.defaults.uniform_access)

  dynamic autoclass {
    for_each = try( each.value.class, local.defaults.class ) == "AUTO" ? toset([1]) : toset([])
    content {
      enabled = true
    }
  }

  dynamic versioning {
    for_each = try( each.value.versioning, local.defaults.versioning ) == true ? toset([1]) : toset([])
    content {
      enabled = true
    }
  }

  #dynamic lifecycle_rule {
  #  for_each = try( each.value.life)
  #}
}

resource "google_storage_managed_folder" "folder" {
  for_each = { for folder in local.folders : folder.folder_id => folder }

  name          = each.value.folder_name
  bucket        = each.value.bucket_id
  force_destroy = try(each.value.destroy, local.defaults.destroy)

  depends_on    = [google_storage_bucket.bucket]
}

#
# PERMISSIONS
#
resource "google_storage_bucket_iam_binding" "iam" {
  for_each = { for access in local.bucket_access : "${access.bucket_id}.${access.role}" => access }

  bucket     = "${var.project.id}-${each.value.bucket_id}"
  role       = each.value.role
  members    = each.value.members

  depends_on = [google_storage_bucket.bucket]
}
