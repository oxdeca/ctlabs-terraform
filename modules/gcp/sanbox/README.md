# GCP Sandbox Platform Module

One-time prerequisites for the **leased sandbox pool** workflow (`vault-gcp sandbox lease|release|reset|list`).

## What it creates

| Resource                          | Purpose                                                                                              |
|-----------------------------------|------------------------------------------------------------------------------------------------------|
| `google_folder.sandbox`           | Sandbox folder — inheritance point for the `roles/editor` roleset binding                            |
| `google_billing_budget.sandbox`   | Folder-scoped budget covering the whole pool (abandoned projects included)                           |
| `google_project.pool`             | Leasable projects `sandbox-pool-01…NN`, **linked to billing at creation**, labels `state=free`       |
| `google_folder_iam_binding.extra` | Optional pre-bindings from `iam_bindings`                                                            |
| sweeper (`sandbox.sweeper`)       | Optional Cloud Scheduler → Cloud Function that disables services and marks expired leases `disabled` |

## Pool lifecycle

```
free → leased → disabled → free
```

Driven purely by `vault-gcp` (JIT token + REST, no gcloud):

- `sandbox lease` — claims the first `state=free` member, sets `owner`/`purpose`/`lease-until` labels and the display name `sbox-<owner>-<purpose>`, enables `--services`.
- `sandbox release` — disables **all** enabled services and sets `state=disabled` (project stays reserved for teardown).
- `sandbox reset` — returns a `disabled` project to `free` after a `terraform destroy` of leftovers.
- `sandbox list --sweep` / the sweeper — same as release, for leases past their TTL.

See `ctlabs-tools/ctlabs_tools/vault/docs/05-gcp-prerequisites.md` for the full bootstrap runbook.

## Configuration

All configuration data is defined by the **consumer** in a `config.yml` and passed into the single `sandbox` object variable (same pattern as `modules/gcp/project` — see e.g. `ctlabs-dev-standalone/main.tf`). Example wrapper root:

```hcl
# <root>/main.tf
locals {
  config = yamldecode(file("./config.yml"))
}

module "sandbox" {
  source = "../modules/gcp/sandbox"
  sandbox = local.config.sandbox
}
```

```yaml
# <root>/config.yml
sandbox:
  name    : sandbox
  billing : 0123AB-4567CD-89EF01
  budget  : 200
  oid     : 123456789012        # or fid: "<parent folder>"
  projects: 5                   # pool size (default 5)
  sweeper:                       # optional TTL enforcement
    project  : gcp-vault-admin-2026042601
    schedule : "0 2 * * *"
    time_zone: UTC
    region   : us-central1
```

Module-internal defaults (budget alert thresholds, sweeper runtime/entry point/names/service list) live in `locals.defaults` in `main.tf`; read the full bootstrap runbook in `ctlabs-tools/ctlabs_tools/vault/docs/05-gcp-prerequisites.md`.
