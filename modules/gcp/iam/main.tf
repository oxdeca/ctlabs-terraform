# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/iam/main.tf
# Description : iam bindings
# -----------------------------------------------------------------------------

resource "gootle_project_iam_custom_role" "custom_role" {
  for_each = { for role in var iam_roles : role.id => role }

  role_id     = each.value.id
  title       = try( each.value.title, null )
  description = try( each.value.desc,  null )
  permissions = try( each.value.perms, [] )
}

resource "google_project_iam_binding" "binding" {
  for_each = { for binding in var.bindings : binding.name => binding }

  project  = var.project.id
  role     = each.value.role
  members  = each.value.members
}

