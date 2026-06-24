# -----------------------------------------------------------------------------
# File: ctlabs-terraform/modules/gcp/gke/test/main.tf
# Desc: testing terraform-module-gcp-gke
# -----------------------------------------------------------------------------

locals {
  config   = yamldecode(file("./config.yml"))
  clusters = { for c in local.config.gke : c.name => c }
}

module "vpcs" {
  source  = "../../net"
  project = { id = local.config.gke[0].project }
  network = local.config.vpc
}

module "gke" {
  for_each = local.clusters

  source = "../"
  gke    = each.value

  depends_on = [module.vpcs]
}

output "endpoints" {
  value = { for name, mod in module.gke : name => mod.cluster_endpoint }
}
