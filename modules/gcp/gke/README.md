# GCP GKE Module

This module provisions a customizable Google Kubernetes Engine (GKE) cluster, supporting both Standard (with Linux and Windows Server node pools) and Autopilot modes.

Required APIs (`container.googleapis.com`, `compute.googleapis.com`) are enabled automatically.

## Examples

### 1. YAML Configuration (`config.yml`)

```yaml
gke:
  project   : my-project
  location  : us-central1-a
  name      : my-cluster
  network   : my-vpc
  subnetwork: my-subnet
  pods_range_name: pods
  svcs_range_name: svcs

  node_pools:
    # Linux pool for system workloads
    - name        : system-pool
      machine_type: e2-medium
      node_count  : 1
      disk_size_gb: 20

    # Windows Server 2022 pool
    - name        : win-pool
      machine_type: e2-standard-2
      node_count  : 1
      disk_size_gb: 50
      image_type  : WINDOWS_LTSC_CONTAINERD
      windows_os_version: OS_VERSION_LTSC2022
```

### 2. Terraform Root (`main.tf`)

```hcl
locals {
  config = yamldecode(file("./config.yml"))
}

module "gke" {
  source = "../"

  gke = local.config.gke
}
```

---

## Inputs

Single config object `gke`:

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
| `machine_type` | `string` | `"e2-medium"` | GCE machine type. |
| `node_count` | `number` | `1` | Number of nodes in the pool. |
| `disk_size_gb` | `number` | `20` | Disk size per node. |
| `disk_type` | `string` | `"pd-standard"` | Disk type (`pd-standard`, `pd-balanced`, `pd-ssd`). |
| `max_pods_per_node` | `number` | `32` | Max Pods per node. |
| `image_type` | `string` | `"COS_CONTAINERD"` | Node OS image. Use `WINDOWS_LTSC_CONTAINERD` for Windows. |
| `windows_os_version` | `string` | `null` | Windows OS version (`OS_VERSION_LTSC2022`). Ignored for Linux pools. |

---

## Outputs

| Output | Description |
| :--- | :--- |
| `cluster_name` | The name of the GKE cluster. |
| `cluster_endpoint` | The IP address of the cluster control plane. |
| `ca_certificate` | The cluster CA certificate (base64 encoded, sensitive). |

---

## Notes

- **Linux pool requirement**: GKE requires at least one Linux node pool for system components. If you define only Windows pools, the module auto-inserts a default Linux pool (`e2-medium`, `COS_CONTAINERD`). If you define both Linux and Windows pools, all are used as-is. Linux-only configs work normally.
- **Windows Server 2022**: use `image_type: WINDOWS_LTSC_CONTAINERD` with `windows_os_version: OS_VERSION_LTSC2022`. Without the version field, GKE defaults to Windows Server 2019.
- **Shielded instances** (`enable_integrity_monitoring`, `enable_secure_boot`) are automatically disabled on Windows node pools, as GKE does not support them for Windows.
- **Provider constraints**: `google >= 7.0, < 8.0`, `kubernetes >= 2.25.2`. Root configs can omit version constraints.
