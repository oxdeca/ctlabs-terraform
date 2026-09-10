# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/sandbox/main.tf
# Description : sandbox platform module (one-time prerequisites for the pooled
#               sandbox workflow: folder + folder-scoped budget + pool projects
#               + optional TTL sweeper)
# -----------------------------------------------------------------------------

locals {
  # defaults (module-internal data; the caller's data arrives via var.sandbox.*)
  defaults = {
    folder_prefix = "sandbox"

    #--- pool -------------------------------------------------------------
    pool = {
      free_name_suffix  = " (free)"          # marker on free pool display names
      labels            = { state = "free" } # required by the lease/release lifecycle
      budget_thresholds = [0.5, 0.9, 1.0]    # budget alerts at 50% / 90% / 100%
    }

    #--- sweeper (static knobs; caller configures project/schedule/tz/region)
    sweeper = {
      name                 = "sandbox-pool-sweeper"
      region               = "us-central1"
      sa_account           = "sbox-sweeper"
      sa_name              = "Sandbox pool sweeper"
      sa_desc              = "Disables services + marks expired leases 'disabled' for the sandbox pool"
      runtime              = "python312"
      entry_point          = "sweep_expired"
      memory               = "128Mi"
      timeout_s            = 300
      ingress              = "ALLOW_ALL"
      http_method          = "GET"
      source_bucket_suffix = "sbox-sweeper-src"
      services = [
        "cloudfunctions.googleapis.com",
        "cloudbuild.googleapis.com",
        "run.googleapis.com",
        "cloudscheduler.googleapis.com",
        "iamcredentials.googleapis.com",
      ]
    }
  }

  # --- derived values (logic) ----------------------------------------------
  parent = (var.sandbox.fid != null && var.sandbox.fid != "") ? "folders/${var.sandbox.fid}" : "organizations/${var.sandbox.oid}"

  # Pool project ids: <prefix>-01 .. <prefix>-NN
  pool_ids = [for i in range(var.sandbox.projects) : format("%s-%02d", var.sandbox.project_prefix, i + 1)]

  # Sweeper helpers (only valid when enabled; guarded by local.sweeper_enabled)
  sweeper_enabled   = var.sandbox.sweeper != null
  sweeper_region    = local.sweeper_enabled ? coalesce(var.sandbox.sweeper.region, local.defaults.sweeper.region) : ""
  sweeper_project   = local.sweeper_enabled ? var.sandbox.sweeper.project : ""
  sweeper_name      = local.defaults.sweeper.name
  sweeper_folder_id = element(split("/", google_folder.sandbox.folder_id), length(split("/", google_folder.sandbox.folder_id)) - 1)
  sweeper_url       = local.sweeper_enabled ? "https://${local.sweeper_region}-${local.sweeper_project}.cloudfunctions.net/${local.sweeper_name}" : ""
}

# -----------------------------------------------------------------------------
# Sandbox Folder (sibling folder that scopes the pool + roleset permissions)
# -----------------------------------------------------------------------------
resource "google_folder" "sandbox" {
  display_name = var.sandbox.name
  parent       = local.parent
}

# -----------------------------------------------------------------------------
# Folder-Level IAM (extra bindings, e.g. a sweeper/billing SA at folder level)
# NOTE: the Vault Broker SA's folder-level grants are delivered by
# `vault-gcp engine create --folder` after this module runs.
# -----------------------------------------------------------------------------
resource "google_folder_iam_binding" "extra" {
  for_each = { for binding in var.sandbox.iam_bindings : binding.role => binding }

  folder  = google_folder.sandbox.folder_id
  role    = each.value.role
  members = each.value.members
}

# -----------------------------------------------------------------------------
# Pool Projects (pre-provisioned leasable sandboxes; billing linked ONCE here)
#   lifecycle: free -> leased -> disabled -> free (driven by vault-gcp sandbox
#   lease|release|reset|list and the optional sweeper below)
# -----------------------------------------------------------------------------
resource "google_project" "pool" {
  count = var.sandbox.projects

  name            = "${local.pool_ids[count.index]}${local.defaults.pool.free_name_suffix}"
  project_id      = local.pool_ids[count.index]
  folder_id       = google_folder.sandbox.folder_id
  billing_account = var.sandbox.billing
  labels          = merge(local.defaults.pool.labels, var.sandbox.pool_labels)
  deletion_policy = var.sandbox.delete_policy
}

# -----------------------------------------------------------------------------
# Folder-Scoped Billing Budget (covers every pool project under the folder)
# -----------------------------------------------------------------------------
resource "google_billing_budget" "sandbox" {
  billing_account = var.sandbox.billing
  display_name    = "Budget - ${google_folder.sandbox.display_name}"

  budget_filter {
    resource_ancestors = [google_folder.sandbox.folder_id]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.sandbox.budget)
    }
  }

  dynamic "threshold_rules" {
    for_each = local.defaults.pool.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }
}

# -----------------------------------------------------------------------------
# TTL Sweeper (optional): Cloud Scheduler -> Cloud Function that disables all
# services and marks 'disabled' any pool project whose lease has expired.
# Runs as a static SA with 'roles/editor' on the sandbox folder.
# -----------------------------------------------------------------------------
resource "google_project_service" "sweeper" {
  for_each = local.sweeper_enabled ? toset(local.defaults.sweeper.services) : toset([])

  project = var.sandbox.sweeper.project
  service = each.key
}

resource "google_service_account" "sweeper" {
  count = local.sweeper_enabled ? 1 : 0

  project      = var.sandbox.sweeper.project
  account_id   = local.defaults.sweeper.sa_account
  display_name = local.defaults.sweeper.sa_name
  description  = local.defaults.sweeper.sa_desc
}

resource "google_folder_iam_binding" "sweeper" {
  count   = local.sweeper_enabled ? 1 : 0
  folder  = google_folder.sandbox.folder_id
  role    = "roles/editor"
  members = ["serviceAccount:${google_service_account.sweeper[0].email}"]
}

resource "google_service_account_iam_binding" "sweeper_self_token_creator" {
  count = local.sweeper_enabled ? 1 : 0

  service_account_id = google_service_account.sweeper[0].name
  role               = "roles/iam.serviceAccountTokenCreator"
  members            = ["serviceAccount:${google_service_account.sweeper[0].email}"]

  depends_on = [google_project_service.sweeper]
}

data "archive_file" "sweeper" {
  count       = local.sweeper_enabled ? 1 : 0
  type        = "zip"
  source_dir          = "${path.module}/functions/sweeper"
  output_path         = "${path.module}/functions/sweeper/.terraform-archive.zip"
}

resource "google_storage_bucket" "sweeper_source" {
  count = local.sweeper_enabled ? 1 : 0

  project                     = var.sandbox.sweeper.project
  name                        = "${var.sandbox.sweeper.project}-${local.defaults.sweeper.source_bucket_suffix}"
  location                    = local.sweeper_region
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "sweeper_code" {
  count      = local.sweeper_enabled ? 1 : 0
  name       = "sweeper-${data.archive_file.sweeper[0].output_md5}.zip"
  bucket     = google_storage_bucket.sweeper_source[0].name
  source     = data.archive_file.sweeper[0].output_path
  depends_on = [google_storage_bucket.sweeper_source]
}

resource "google_cloudfunctions2_function" "sweeper" {
  count    = local.sweeper_enabled ? 1 : 0
  project  = var.sandbox.sweeper.project
  name     = local.defaults.sweeper.name
  location = local.sweeper_region

  description = local.defaults.sweeper.sa_desc

  build_config {
    runtime     = local.defaults.sweeper.runtime
    entry_point = local.defaults.sweeper.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.sweeper_source[0].name
        object = google_storage_bucket_object.sweeper_code[0].name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = local.defaults.sweeper.memory
    timeout_seconds       = local.defaults.sweeper.timeout_s
    service_account_email = google_service_account.sweeper[0].email
    ingress_settings      = local.defaults.sweeper.ingress
    environment_variables = {
      FOLDER_ID = local.sweeper_folder_id
    }
  }

  depends_on = [google_project_service.sweeper, google_storage_bucket_object.sweeper_code, google_service_account_iam_binding.sweeper_self_token_creator]
}

resource "google_cloudfunctions2_function_iam_member" "sweeper_invoker" {
  count = local.sweeper_enabled ? 1 : 0

  project        = var.sandbox.sweeper.project
  location       = local.sweeper_region
  cloud_function = local.defaults.sweeper.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.sweeper[0].email}"

  depends_on = [google_cloudfunctions2_function.sweeper]
}

resource "google_cloud_scheduler_job" "sweeper" {
  count = local.sweeper_enabled ? 1 : 0

  project   = var.sandbox.sweeper.project
  region    = local.sweeper_region
  name      = local.defaults.sweeper.name
  schedule  = var.sandbox.sweeper.schedule
  time_zone = var.sandbox.sweeper.time_zone

  http_target {
    http_method = local.defaults.sweeper.http_method
    uri         = local.sweeper_url
    oidc_token {
      service_account_email = google_service_account.sweeper[0].email
      audience              = local.sweeper_url
    }
  }

  depends_on = [google_project_service.sweeper, google_cloudfunctions2_function.sweeper, google_service_account_iam_binding.sweeper_self_token_creator]
}

# -----------------------------------------------------------------------------

output "folder_id" {
  description = "Full resource name of the sandbox folder (e.g. folders/1234567890)"
  value       = google_folder.sandbox.folder_id
}

output "pool_ids" {
  description = "Project IDs of the leasable sandbox pool"
  value       = [google_project.pool[*].project_id]
}

output "sweeper_url" {
  description = "Optional TTL sweeper HTTP endpoint"
  value       = local.sweeper_url
}
