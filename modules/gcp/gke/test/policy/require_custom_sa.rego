package main

deny contains msg if {
  some resource in input.resource_changes
  resource.type == "google_container_cluster"
  "create" in resource.change.actions
  not resource.change.after.node_config[0].service_account
  msg := sprintf("Cluster %v must use a custom service account (not the default compute SA)", [resource.change.after.name])
}
