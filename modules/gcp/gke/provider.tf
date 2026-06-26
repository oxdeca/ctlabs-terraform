# -----------------------------------------------------------------------------
# File  : ctlabs-terraform/modules/gcp/gke/provider.tf
# Desc  : required providers
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25.2"
    }
  }
}
