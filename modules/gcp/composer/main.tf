# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/composer/main.tf
# Description : composer module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    roles      = toset( ["composer.worker"] )      
    sa_prefix  = "composer-"
    sa_postfix = "@${var.project.id}.iam.gserviceaccount.com"
  }
}

# ---
# 
# if we use a shared vpc we need to make suer the service identity of the service project
# have access to the subnet in the host project

resource "google_project_service_identity" "composer_agent" {
  provider = google-beta
  project  = var.project.id
  service  = "composer.googleapis.com"
}

resource "google_project_iam_member" "composer_agent_sa" {
  project = try( var.project.shared_vpc, var.project.id )
  role    = "roles/composer.sharedVpcAgent"
  member  = google_project_service_identity.composer_agent.member
}

resource "google_service_account" "sa" {
  for_each = { for env in var.composer.envs : env.name => env }

  account_id   = "${local.defaults.sa_prefix}${each.value.name}"
  display_name = try( each.value.name, null )
  description  = try( each.value.desc, null )
}

resource "google_project_iam_member" "access" {
  for_each = { for env in var.composer.envs : env.name => env }

  project = var.project.id
  member  = "serviceAccount:${google_service_account.sa[each.value.name].email}"
  role    = "roles/composer.worker"

  depends_on = [google_service_account.sa]
}

resource "google_composer_environment" "env" {
  for_each = { for env in var.composer.envs : env.name => env }

  name = each.value.name

  config {
    software_config {
      image_version = each.value.image
    }

    node_config {
      service_account = "${google_service_account.sa[each.value.name].email}"
    }
  }

  depends_on = [google_service_account.sa, google_project_iam_member.access]
}
