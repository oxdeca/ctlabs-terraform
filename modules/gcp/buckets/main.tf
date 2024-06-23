# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/storage/main.tf
# Description : storage module
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "bucket" {
  for_each = { for bucket in var.buckets : bucket.name => bucket }

  name          = each.value.name
  location      = each.value.location
  storage_class = each.value.storage_class
  labels        = each.value.labels
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
