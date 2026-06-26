# -----------------------------------------------------------------------------
# File : ctlabs-terraform/modules/gcp/gke/test/provider.tf
# Desc : provider configuration
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
