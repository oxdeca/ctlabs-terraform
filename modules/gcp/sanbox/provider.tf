# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/sandbox/provider.tf
# Description : sandbox platform module providers
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.13.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }
}
