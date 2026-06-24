package main

deny contains msg if {
  some resource in input.resource_changes
  resource.type == "google_container_cluster"
  "create" in resource.change.actions
  config := resource.change.after.private_cluster_config
  count(config) > 0
  config[0].enable_private_nodes == true
  not config[0].master_ipv4_cidr_block
  msg := sprintf("Private cluster %v must specify master_ipv4_cidr_block", [resource.change.after.name])
}

deny contains msg if {
  some resource in input.resource_changes
  resource.type == "google_container_cluster"
  "create" in resource.change.actions
  config := resource.change.after.private_cluster_config
  count(config) > 0
  config[0].enable_private_nodes == true
  cidr := config[0].master_ipv4_cidr_block
  not endswith(cidr, "/28")
  msg := sprintf("Private cluster %v master CIDR %v must be a /28", [resource.change.after.name, cidr])
}
