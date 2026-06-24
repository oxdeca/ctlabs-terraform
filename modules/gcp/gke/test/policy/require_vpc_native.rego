package main

deny contains msg if {
  some resource in input.resource_changes
  resource.type == "google_container_cluster"
  "create" in resource.change.actions
  not resource.change.after.ip_allocation_policy
  msg := sprintf("Cluster %v must use VPC-native (alias IP) networking — set pods_range_name and svcs_range_name", [resource.change.after.name])
}
