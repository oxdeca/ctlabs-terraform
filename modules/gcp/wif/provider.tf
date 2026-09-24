# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/wif/provider.tf
# Description : wif module required providers
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0"
    }
  }
}
