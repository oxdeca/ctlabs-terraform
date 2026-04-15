# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/main.tf
# Description : project module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    labels = {
      module = "ctlabs-terraform-module-gcp-project"
    }
    services = [
      "compute.googleapis.com",
      "iam.googleapis.com",
      "cloudresourcemanager.googleapis.com"
    ]
    format_iam_uri = {
      for rule in var.project.iam.deny_rules : rule.id => {
        denied = [
          for p in rule.denied_principals : 
            p.type == "set"  ? "principalSet://goog/${p.id}" :
            p.type == "group" ? "principalSet://goog/group/${p.id}" :
            "principal://iam.googleapis.com/projects/-/serviceAccounts/${p.id}"
        ]
        exceptions = [
          for e in try(rule.exceptions, []) :
            e.type == "set"  ? "principalSet://goog/${e.id}" :
            e.type == "group" ? "principalSet://goog/group/${e.id}" :
            "principal://iam.googleapis.com/projects/-/serviceAccounts/${e.id}"
        ]
      }
    }
  }

  project_name = coalesce(var.project.name, var.project.id)
  project_id   = coalesce(var.project.id,   var.project.name)

  custom_roles = {
    for id, role in google_project_iam_custom_role.role : "roles/${id}" => role.id
  }
}

# -----------------------------------------------------------------------------

resource "google_project" "project" {
  name                = local.project_name
  project_id          = local.project_id
  billing_account     = var.project.billing
  org_id              = try(var.project.fid, null) == null ? var.project.oid : null
  folder_id           = try(var.project.oid, null) == null ? var.project.fid : null
  labels              = merge(local.defaults.labels, try(var.project.labels, null))
  deletion_policy     = var.project.delete_policy
  auto_create_network = var.project.create_network
}

# -----------------------------------------------------------------------------
# Google API's (Services)
# -----------------------------------------------------------------------------
resource "google_project_service" "service" {
  for_each = toset(concat(local.defaults.services, var.project.services))

  project  = local.project_id
  service  = each.key

  timeouts {
    create = "30m"
    delete = "30m"
  }

  depends_on = [google_project.project]
}

# -----------------------------------------------------------------------------
# Delete Default Service Account
# -----------------------------------------------------------------------------
resource "google_project_default_service_accounts" "sa" {
  count = try(var.project.sa_delete, local.defaults.sa_delete) ? 1 : 0

  project        = local.project_id
  action         = "DELETE"
  restore_policy = "REVERT"

  depends_on     = [google_project.project, google_project_service.service]
}

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------
resource "google_service_account" "sa" {
  for_each = { for sa in var.project.service_accounts : sa.name => sa }

  project      = local.project_id
  account_id   = each.value.id
  display_name = try(each.value.name, null)
  description  = try(each.value.desc, null)

  depends_on = [google_project.project, google_project_service.service]
}

# -----------------------------------------------------------------------------
# Project Type (Standalone-, Host-, Service-Project)
# -----------------------------------------------------------------------------
resource "google_compute_shared_vpc_host_project" "host_project" {
  count = var.project.type == "host" ? 1 : 0

  project = local.project_id

  depends_on = [google_project.project, google_project_service.service]
}

resource "google_compute_shared_vpc_service_project" "service_project" {
  count = var.project.type == "service" ? 1 : 0

  host_project    = var.project.host_project
  service_project = local.project_id

  depends_on = [google_project.project, google_project_service.service]
}

# -----------------------------------------------------------------------------
# IAM - Custom Roles
# -----------------------------------------------------------------------------
resource "google_project_iam_custom_role" "role" {
  for_each = { for role in var.project.iam.roles : role.id => role }

  project     = local.project_id
  role_id     = each.value.id
  title       = each.value.title
  permissions = each.value.perms
  description = each.value.desc
}

# -----------------------------------------------------------------------------
# IAM - Project-Level Permissions
# -----------------------------------------------------------------------------
resource "google_project_iam_binding" "binding" {
  for_each = { for binding in var.project.iam.bindings : binding.role => binding }

  project = local.project_id
  role    = try(local.custom_roles[each.value.role], each.value.role)
  members = [for member in each.value.members : member]

  depends_on = [google_project_iam_custom_role.role, google_service_account.sa]
}

# -----------------------------------------------------------------------------
# IAM - Project-Level Deny Rules
# -----------------------------------------------------------------------------
resource "google_iam_deny_policy" "deny_rules" {
  for_each = { for r in var.project.iam.deny_rules : r.id => r }

  parent       = urlencode("cloudresourcemanager.googleapis.com/projects/${local.project_id}")
  name         = "deny-${each.key}"
  
  rules {
    deny_rule {
      denied_permissions = each.value.perms
      denied_principals  = local.format_iam_uri[each.key].denied
      
      # We automatically inject the "Safe" project SA exception alongside their YAML exceptions
      exception_principals = distinct(concat(
        local.format_iam_uri[each.key].exceptions,
        ["principalSet://goog/projects/${google_project.project.number}/serviceAccounts"]
      ))
    }
  }
}
