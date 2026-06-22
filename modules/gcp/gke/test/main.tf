# -----------------------------------------------------------------------------
# File: ctlabs-terraform/modules/gcp/gke/test/main.tf
# Desc: testing terraform-module-gcp-gke
# -----------------------------------------------------------------------------

locals {
  config = yamldecode(file("./config.yml"))
}

module "vpc" {
  source  = "../../net"
  project = { id = local.config.gke.project }
  network = local.config.vpc
}

module "gke" {
  source = "../"

  gke = local.config.gke

  depends_on = [module.vpc]
}

# Optional: Export the endpoint for quick verification
output "endpoint" {
  value = module.gke.cluster_endpoint
}
