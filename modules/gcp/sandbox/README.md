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

## `delete_policy` and recovering from a broken state

`google_project.pool` members default to `deletion_policy = "ABANDON"`. Never use `"PREVENT"` (the
`google_project` default) here: it makes `terraform destroy`/`terraform state rm`-adjacent operations
error out entirely rather than just leaving the real project alone, which blocks recovering from a
partial/broken apply. `"DELETE"` is also wrong — the whole point of the pool is that real projects
outlive Terraform's state.

If the state ever needs to be reset (e.g. after a partial apply, or to fix a module bug), the pool
projects and folder **still exist for real in GCP** even after `terraform destroy` state-abandons them
— project ids and the folder are not freed up for reuse (30-day soft delete quota either way), so the
next `apply` must NOT try to create them again. Bring them back with `import` blocks instead of letting
`apply` fail on "already exists":

```hcl
import {
  to = module.sandbox.google_folder.sandbox
  id = "folders/<existing-folder-id>"
}

import {
  to = module.sandbox.google_project.pool[0]
  id = "sandbox-pool-01"
}
# ...repeat per pool index
```

Run `terraform plan` after adding these — it should show the import reconciling into the existing
resource with no diff (aside from any fields you're intentionally changing, e.g. `delete_policy`),
not a create.

## One-time admin permissions (verified live end-to-end 2026-09-25)

This module's apply is a **one-time bootstrap**, run once by a dedicated identity - not something
re-applied routinely. Day-to-day pool lease/release is a completely separate, lower-privilege flow
(`roles/editor` at the sandbox folder, via `vault-gcp`/ctlabs-tools Python, JIT tokens).

A full apply (folder already existed, 4 pool projects, budget, full sweeper stack: services, SA,
storage bucket/object, Cloud Function gen2, Cloud Scheduler, all relevant IAM) was completed with the
bootstrap identity (`terraform-runner`, a WIF-impersonated SA - see below) holding exactly these grants,
made by hand outside Terraform (see why, further down):

| Scope                                          | Role                                      | Why                                                                    |
|--------------------------------------------------|--------------------------------------------|---------------------------------------------------------------------------|
| Sandbox folder                                    | `roles/resourcemanager.projectCreator`     | create `google_project.pool` members (only matters for genuinely new pool projects) |
| Sandbox folder                                    | `roles/resourcemanager.folderViewer`       | `projectCreator` alone lacks `resourcemanager.folders.get`             |
| Sandbox folder                                    | `roles/billing.projectManager`             | project-side half of the billing link (`resourcemanager.projects.createBillingAssignment`) - needed for pool projects that predate this identity, since only the *actual creator* of a project gets this automatically |
| Sandbox folder                                    | `roles/editor`                             | general in-place project attribute updates (billing_account/deletion_policy/name/labels) on pool projects this identity didn't create - `projectCreator`+`folderViewer`+`billing.projectManager` alone are not enough for a plain `projects.patch` |
| Billing account (whichever is linked)             | `roles/billing.user`                       | link each pool project to billing (`billing.resourceAssociations.create`) |
| Billing account (whichever is linked)             | `roles/billing.costsManager`               | create `google_billing_budget.sandbox`                                 |
| `ctlabs-security` (the bootstrap identity's own home project) | `roles/editor` (pre-existing, general use) | most create/update ops there                                           |
| `ctlabs-security`                                 | `roles/billing.projectManager`             | project-side half of the billing link, for `ctlabs-security` itself    |
| `ctlabs-security`                                 | `roles/iam.serviceAccountAdmin`            | `Editor` excludes `iam.serviceAccounts.setIamPolicy` - needed for the sweeper SA's self-`serviceAccountTokenCreator` binding |
| `ctlabs-security`                                 | `roles/resourcemanager.projectIamAdmin`    | `Editor` excludes project-level `setIamPolicy` generally - needed for the sweeper build's storage/artifactregistry/logging grants (see below) |
| `ctlabs-security`                                 | `roles/cloudfunctions.admin`               | Cloud Functions has its **own** resource-level IAM (`cloudfunctions.functions.setIamPolicy`) - `projectIamAdmin` (project-level policy) does not cover it; needed for `google_cloudfunctions2_function_iam_member.sweeper_invoker` |

**Why manual, never as `google_*_iam_member`/`_binding` resources managed by this same identity**: every
one of these is itself an IAM-policy-management permission (`GetIamPolicy`/`SetIamPolicy` at some scope).
An identity can't grant itself a permission it doesn't already have, and granting it broad enough IAM-admin
scope to self-provision would be a standing self-escalation path - exactly what keeping the identity in a
separate project (see below) exists to avoid. This is a real, hard rule, not caution: every attempt to
codify one of these grants as a `google_folder_iam_member`/`google_billing_account_iam_member` resource
under `terraform-runner`'s own plan failed with the matching `GetIamPolicy`/`SetIamPolicy` permission
denied, regardless of what other roles it already had.

### sbox-sweeper's own permissions (separate identity, granted BY this module)

The sweeper SA (`sbox-sweeper`, created fresh by this module) needs its own grants, since
`project.sa_delete = true` deletes the default compute SA it would otherwise fall back on for the Cloud
Build step:

| Scope                              | Role                             | Why                                                        |
|-------------------------------------|-----------------------------------|---------------------------------------------------------------|
| Self (service account)              | `roles/iam.serviceAccountTokenCreator` | the function/scheduler need to mint their own OIDC tokens |
| `sandbox.sweeper.project`            | `roles/storage.objectViewer`     | Cloud Build reads sources from the auto-created `gcf-v2-sources-*` bucket |
| `sandbox.sweeper.project`            | `roles/artifactregistry.writer`  | Cloud Build pushes the built image to the `gcf-artifacts` repo |
| `sandbox.sweeper.project`            | `roles/logging.logWriter`        | write build/runtime logs (Cloud Build itself warns if this is missing) |
| Sandbox folder                       | `roles/editor`                   | the sweeper's actual job: disable services + relabel expired pool members. Same self-escalation problem as above applies here too - `var.sandbox.sweeper.skip_folder_grant = true` skips `google_folder_iam_binding.sweeper` and this grant must be made manually |

Known gotcha already hit once: `sandbox.sweeper.project` must be a **real, already-existing** project —
it is not created by this module. Pointing it at a project that doesn't exist yet (e.g. one whose
creation module is commented out) will fail the sweeper stage regardless of IAM.

Also hit live: `google_billing_budget`'s `budget_filter.resource_ancestors` needs the fully-qualified
`folders/<id>` form - `google_folder.sandbox.folder_id` is the bare numeric ID, so use
`"folders/${local.sweeper_folder_id}"` (or equivalent), not the raw output, or budget creation 400s with
an opaque "invalid argument". And `google_billing_budget.amount.specified_amount.currency_code` (now
`var.sandbox.budget_currency`) must match the billing account's actual currency, or the same opaque 400.

### Where the bootstrap identity should live

Keep the bootstrap identity (a WIF-impersonated SA, e.g. `terraform-runner`) in a **separate project**
from the sandbox folder it administers (e.g. `ctlabs-security`, never inside the sandbox folder or a
project under it). This is the actual security property: to modify/hijack that SA, you need IAM rights
in `ctlabs-security`, which is completely outside the blast radius of anyone who breaks out of a leased
sandbox project. This holds under WIF exactly as much as it did under the Vault GCP secrets engine (JIT)
path — WIF only changes how the ephemeral credential is obtained (Vault-signed JWT + impersonation
instead of a roleset key), not where the impersonated SA should live.

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
