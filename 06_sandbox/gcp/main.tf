# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/gcp/06_sandbox/main.tf
# Description : terraform configuration to provision sandbox projects
# -----------------------------------------------------------------------------

import {
  to = module.ctlabs-security.google_project.project
  id = "ctlabs-security"
}

locals {
  vault = {
    url        = "https://192.168.99.5:8200"
    mount      = "kvv2"
    tls_verify = false
    secrets = [{
      name = "ctlabs-security"
      path = "dev/sandbox"
      type = "data"
    }]
  }

  config = yamldecode(templatefile("./config.yml", {
    billing  = module.vault.data_secrets["ctlabs-security"].billing
    folder   = module.vault.data_secrets["ctlabs-security"].folder
    oid      = module.vault.data_secrets["ctlabs-security"].oid
    ssh_keys = module.vault.data_secrets["ctlabs-security"].ssh_keys
  }))
}

module "ctlabs-security" {
  source  = "../../modules/gcp/project"
  project = nonsensitive(local.config.project)
}

module "sandbox" {
  source     = "../../modules/gcp/sandbox"
  sandbox    = nonsensitive(local.config.sandbox)
  depends_on = [module.ctlabs-security]
}

module "vault" {
  #source = "../../modules/gcp/vault"
  source = "github.com/oxdeca/ctlabs-terraform/modules/gcp/vault?ref=dev"
  vault  = local.vault
}

# -----------------------------------------------------------------------------
# sandbox-admin bootstrap permissions (NOT managed here - see below)
#
# `terraform-runner@ctlabs-security.iam.gserviceaccount.com` (the existing WIF
# SA - `ctlabs-vault-pool`, from `scripts/gcp_wif_setup.py`, not this repo) is
# the one-time bootstrap identity for this whole config. It was granted, once,
# by hand (a human with folder/billing IAM-admin rights - NOT this SA):
#   gcloud resource-manager folders add-iam-policy-binding 801342900631 \
#     --member="serviceAccount:terraform-runner@ctlabs-security.iam.gserviceaccount.com" \
#     --role="roles/resourcemanager.projectCreator"
#   gcloud resource-manager folders add-iam-policy-binding 801342900631 \
#     --member="serviceAccount:terraform-runner@ctlabs-security.iam.gserviceaccount.com" \
#     --role="roles/resourcemanager.folderViewer"
#   gcloud billing accounts add-iam-policy-binding 01A9AC-051C49-3D9258 \
#     --member="serviceAccount:terraform-runner@ctlabs-security.iam.gserviceaccount.com" \
#     --role="roles/billing.user"
#   gcloud billing accounts add-iam-policy-binding 01A9AC-051C49-3D9258 \
#     --member="serviceAccount:terraform-runner@ctlabs-security.iam.gserviceaccount.com" \
#     --role="roles/billing.costsManager"
#
# These 4 roles are NOT codified as google_folder_iam_member /
# google_billing_account_iam_member resources here on purpose: managing them
# requires GetIamPolicy/SetIamPolicy on the folder/billing account, a
# strictly higher privilege tier (folderIamAdmin / billing.admin) than any of
# the 4 roles themselves grant - terraform-runner can never self-manage its
# own grant this way, by design (it shouldn't hold IAM-admin over itself).
# This is a one-time bootstrap; once this config has applied successfully,
# nothing needs standing folder/billing IAM access again - day-to-day pool
# lease/release runs on the separate, lower-privilege JIT flow
# (`roles/editor` at the folder, via vault-gcp / ctlabs-tools Python), unrelated
# to this SA. NOTE: this SA is shared with 2 other Vault entities as of
# 2026-09-25 - these 4 roles widen what all of them can do through it.
# -----------------------------------------------------------------------------
