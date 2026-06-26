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

  # Optional: private cluster with /28 master range
  private_cluster:
    master_cidr: 172.16.0.0/28
    enable_private_endpoint: false
    master_global_access: false
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
| `private_cluster` | `object` | `null` | Private cluster config. When set, creates a private cluster. See below. |
| `node_pools` | `list(object)` | See below | List of GKE node pool definitions. |

### `private_cluster` attributes:

| Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `master_cidr` | `string` | *Required* | `/28` CIDR block for the GKE master control plane. |
| `enable_private_endpoint` | `bool` | `false` | Whether the cluster endpoint is private. `false` = public endpoint with private nodes. |
| `master_global_access` | `bool` | `false` | Enable global access for the private master endpoint. |

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

## Subnet Sizing Guide

VPC-Native GKE clusters consume IP addresses from three ranges on the subnetwork. Use this guide to pick CIDR sizes.

### Range Overview

| Range | Purpose | Consumer | Sizing Factor |
| :--- | :--- | :--- | :--- |
| **Primary** | Node IPs | 1 IP per node | `nodes` |
| **Pods** | Pod IPs | `max_pods_per_node` IPs per node | `nodes × max_pods_per_node` |
| **Services** | ClusterIP services | 1 IP per service | `services` (typically small) |
| **Master** | Control plane (private only) | Always `/28` | Fixed |

### Recommended CIDR Sizes

| Cluster Size | Nodes | Pods (/24 per node) | Services | Primary | Pods | Services | Master (private) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Small | 1–10 | 32 | 10–20 | `/24` | `/22` | `/26` | `/28` |
| Medium | 10–50 | 32 | 20–50 | `/23` | `/21` | `/25` | `/28` |
| Large | 50–200 | 32 | 50–200 | `/22` | `/19` | `/24` | `/28` |
| X-Large | 200–1000 | 32 | 200–500 | `/20` | `/17` | `/23` | `/28` |

> `max_pods_per_node = 32` is the default. If you raise it, scale the pods range accordingly. Each increase doubles the per-node pod IP pool (e.g. 64 pods/node → pods range needs 2× more IPs).

### Private Cluster Additions

A private cluster adds one `/28` master CIDR block. This block must not overlap with any VPC range. Common choices:

- `172.16.0.0/28` (isolated RFC 1918 space)
- A non-overlapping slice of your VPC's address space

### Example: Medium Cluster, Private

```yaml
gke:
  private_cluster:
    master_cidr: 172.16.0.0/28

vpc:
  - subnets:
      - cidr: 10.0.0.0/23      # 512 node IPs — room for 50 nodes + growth
        ranges:
          - name: pods
            cidr: 10.1.0.0/21   # 2048 pod IPs — 50 nodes × 32 = 1600
          - name: svcs
            cidr: 10.2.0.0/25   # 128 service IPs — plenty
```

---

## Notes

- **Linux pool requirement**: GKE requires at least one Linux node pool for system components. If you define only Windows pools, the module auto-inserts a default Linux pool (`e2-medium`, `COS_CONTAINERD`). If you define both Linux and Windows pools, all are used as-is. Linux-only configs work normally.
- **Windows Server 2022**: use `image_type: WINDOWS_LTSC_CONTAINERD` with `windows_os_version: OS_VERSION_LTSC2022`. Without the version field, GKE defaults to Windows Server 2019.
- **Shielded instances** (`enable_integrity_monitoring`, `enable_secure_boot`) are automatically disabled on Windows node pools, as GKE does not support them for Windows.
- **Provider constraints**: `google >= 7.0, < 8.0`, `kubernetes >= 2.25.2`. Root configs can omit version constraints.
