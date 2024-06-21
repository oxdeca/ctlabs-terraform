# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/bigquery/main.tf
# Description : bigquery module
# -----------------------------------------------------------------------------

resource "google_bigquery_dataset" "ds" {
  for_each = { for ds in var.datasets : ds.name => ds }

  project                    = var.project.id
  dataset_id                 = each.value.name
  friendly_name              = try( each.value.friendly )
  delete_contents_on_destroy = try( each.value.destroy  )
  location                   = try( each.value.location )
  labels                     = try( each.value.labels   )
}

resource "google_bigquery_table" "tables" {
  for_each = { for table in var.tables : table.name => table }

  project             = var.project.id
  dataset_id          = "${split(".", each.value.name)[0]}"
  table_id            = "${split(".", each.value.name)[1]}"
  deletion_protection = each.value.delete
  expiration_time     = try( each.value.schema, 1000*1000 )
  schema              = try( "${jsonencode(each.value.schema)}", null )
  labels              = try( each.value.labels )

  depends_on          = [google_bigquery_dataset.ds]
}

resource "google_bigquery_dataset_iam_binding" "ds_access" {
  for_each = { for access in var.dataset_iam : "${access.name}_${access.role}" => access }

  role       = each.value.role
  dataset_id = each.value.name
  members    = each.value.members

  depends_on = [google_bigquery_dataset.ds]
}

resource "google_bigquery_table_iam_binding" "table_access" {
  for_each = { for access in var.table_iam : "${access.name}_${access.role}" => access }

  role       = each.value.role
  dataset_id = "${split(".", each.value.name)[0]}"
  table_id   = "${split(".", each.value.name)[1]}"
  members    = each.value.members
  
  depends_on = [google_bigquery_table.tables]
}
