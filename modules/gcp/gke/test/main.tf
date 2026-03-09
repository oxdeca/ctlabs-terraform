# -----------------------------------------------------------------------------
# File: ctlabs-terraform/gke/test/main.tf
# Desc: testing terraform-module-gcp-gke
# -----------------------------------------------------------------------------

locals { 
  config = yamldecode(file("./config.yml")) 
}

module "gke" {
  source = "../../modules/gcp/gke"

  gke = local.config.gke
}

# Optional: Export the endpoint for quick verification
output "endpoint" {
  value = module.gke.cluster_endpoint
}
