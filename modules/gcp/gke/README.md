# GCP GKE Module

This module provisions a minimal, customizable Google Kubernetes Engine (GKE) cluster, supporting both Standard (with managed Linux and Windows Server node pools) and Autopilot modes.

The services/APIs required for GKE (such as `container.googleapis.com` and `compute.googleapis.com`) are automatically enabled by the module internally.

## Examples

### 1. YAML Configuration (`config.yml`)

The GKE configuration object is defined under the `gke` key. This example configures a VPC-native cluster with one Linux system pool and one Windows application node pool:

```yaml
---
# -----------------------------------------------------------------------------
# File        : config.yml
# Description : Configuration for GKE Cluster with Linux and Windows node pools
# -----------------------------------------------------------------------------

gke:
  project: ctlabs-prj-2025101601
  location: us-central1-a
  name: dev-cluster-01
  network: default
  subnetwork: default
  deletion_protection: false
  
  # VPC-Native Cluster Routing (Secondary ranges required for GKE pods and services)
  pods_range_name: gke-pods-range
  svcs_range_name: gke-services-range

  # Managed Node Pool Definitions
  node_pools:
    - name: system-pool
      machine_type: e2-medium
      node_count: 1
      disk_size_gb: 20
      disk_type: pd-standard
      image_type: COS_CONTAINERD         # Linux nodes for core system workloads

    - name: win-pool
      machine_type: e2-standard-2
      node_count: 1
      disk_size_gb: 50
      disk_type: pd-standard
      image_type: WINDOWS_LTSC_CONTAINERD # Windows nodes for legacy Windows workloads
```

### 2. Terraform Configuration (`main.tf`)

Load the config YAML and pass it directly to the GKE module:

```hcl
# -----------------------------------------------------------------------------
# File        : main.tf
# Description : Terraform root configuration calling the GKE module
# -----------------------------------------------------------------------------

locals { 
  config = yamldecode(file("./config.yml")) 
}

module "gke" {
  source = "github.com/oxdeca/ctlabs-terraform/modules/gcp/gke?ref=dev"

  gke = local.config.gke
}

output "endpoint" {
  value       = module.gke.cluster_endpoint
  description = "The IP address of the GKE cluster control plane."
}
```

---

## Inputs

The module expects a single configuration object `gke` defined in [variables.tf](file:///root/ctlabs-terraform/modules/gcp/gke/variables.tf):

| Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `project` | `string` | *Required* | GCP Project ID. |
| `location` | `string` | *Required* | GCP Region or Zone. |
| `name` | `string` | *Required* | Name of the GKE cluster. |
| `network` | `string` | `"default"` | Network name or self link. |
| `subnetwork` | `string` | `"default"` | Subnetwork name or self link. |
| `autopilot` | `bool` | `false` | Enable GKE Autopilot mode. |
| `deletion_protection` | `bool` | `false` | Enable cluster deletion protection. |
| `pods_range_name` | `string` | `null` | Secondary IP range name for Pods (VPC-Native). |
| `svcs_range_name` | `string` | `null` | Secondary IP range name for Services (VPC-Native). |
| `master_cidr` | `string` | `null` | IP range for the GKE master (Private Cluster). |
| `node_pools` | `list(object)` | See below | List of GKE node pool definitions. |

### `node_pools` attributes:

| Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `name` | `string` | *Required* | Name of the node pool. |
| `machine_type` | `string` | `"e2-medium"` | The name of a Google Compute Engine machine type. |
| `node_count` | `number` | `1` | The number of nodes in the pool. |
| `disk_size_gb` | `number` | `20` | Size of the disk attached to each node. |
| `disk_type` | `string` | `"pd-standard"` | Type of disk attached to each node (`pd-standard`, `pd-balanced`, `pd-ssd`). |
| `max_pods_per_node` | `number` | `32` | Maximum number of Pods per node. |
| `image_type` | `string` | `"COS_CONTAINERD"` | Base OS image for nodes (`COS_CONTAINERD`, `UBUNTU_CONTAINERD`, `WINDOWS_LTSC_CONTAINERD`). |

---

## Outputs

| Output | Description |
| :--- | :--- |
| `cluster_name` | The name of the GKE cluster. |
| `cluster_endpoint` | The IP address of the cluster control plane. |
| `ca_certificate` | The cluster CA certificate (base64 encoded, sensitive). |
