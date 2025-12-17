# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/provider.tf
# Description : project module
# -----------------------------------------------------------------------------

terraform {
	required_providers {
		google = {
			source  = "hashicorp/google"
			version = "7.13.0"
		}
	}
}
