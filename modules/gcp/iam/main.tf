# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/iam/main.tf
# Description : iam bindings
# -----------------------------------------------------------------------------

resource "google_project_iam_custom_role" "role" {
  for_each = { for role in var.roles : role.id => role }

  role_id     = each.value.id
  title       = try( each.value.title, null )
  description = try( each.value.desc,  null )
  permissions = try( each.value.perms, [] )
}

resource "google_project_iam_binding" "binding" {
  for_each = { for binding in var.bindings : binding.role => binding }

  project    = var.project.id
  role       = each.value.role
  members    = each.value.members
  depends_on = [google_project_iam_custom_role.role]
}

