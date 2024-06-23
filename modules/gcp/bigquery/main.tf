# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/bigquery/main.tf
# Description : bigquery module
# -----------------------------------------------------------------------------

locals {
  tables         = flatten( [ for dsk, dsv in var.bigquery : [ for table  in dsv.tables : merge( { dataset_id = dsk, table_id = table.name }, table ) ] ] )
  table_access   = flatten( [ for dsk, dsv in var.bigquery : [ for table  in dsv.tables : [ for access in table.access : merge( { dataset_id = dsk, table_id = table.name }, access ) ] ] ] )
  dataset_access = flatten( [ for dsk, dsv in var.bigquery : [ for access in dsv.access : merge( { dataset_id = dsk }, access ) ] ] )
}

resource "google_bigquery_dataset" "ds" {
  for_each = { for dataset_id, dataset in var.bigquery : dataset_id => dataset }

  project                    = var.project.id
  dataset_id                 = each.key
  description                = try( each.value.desc,     null )
  friendly_name              = try( each.value.friendly, null )
  delete_contents_on_destroy = try( each.value.destroy,  null )
  location                   = try( each.value.location, null )
  labels                     = try( each.value.labels,   null )
}

resource "google_bigquery_table" "tables" {
  for_each = { for table in local.tables : "${table.dataset_id}.${table.table_id}" => table }

  project             = var.project.id
  dataset_id          = each.value.dataset_id
  table_id            = each.value.table_id
  deletion_protection = try( each.value.delete, false )
  #expiration_time     = try( each.value.schema, 1000*1000 )
  schema              = try( "${jsonencode(each.value.schema)}", null )
  labels              = try( each.value.labels )

  dynamic table_constraints {
    for_each = lookup(each.value, "constraints", [])
    content {
      primary_key {
        columns =  try( each.value.constraints.primary_key, [] )
      }
    }
  }

  depends_on = [google_bigquery_dataset.ds]
}

resource "google_bigquery_dataset_iam_binding" "dataset_access" {
  for_each = { for access in local.dataset_access : "${access.dataset_id}.${access.role}" => access }

  dataset_id = each.value.dataset_id
  role       = try( each.value.role,    null )
  members    = try( each.value.members, null )

  depends_on = [google_bigquery_dataset.ds]
}

resource "google_bigquery_table_iam_binding" "table_access" {
  for_each = { for access in local.table_access : "${access.dataset_id}.${access.table_id}" => access }

  dataset_id = each.value.dataset_id
  table_id   = each.value.table_id
  role       = try( each.value.role,    null )
  members    = try( each.value.members, null )

  depends_on = [google_bigquery_table.tables]
}
