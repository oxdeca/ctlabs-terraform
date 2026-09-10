"""Sandbox pool sweeper: disable services and mark expired leases 'disabled'.

Lifecycle: free -> leased -> disabled -> free.
This function is invoked periodically by Cloud Scheduler. For every pool
project whose label state == 'leased' and lease-until is in the past it:
  1. disables ALL enabled API services (so the project stops spending), and
  2. PATCHes the project: labels.state = disabled (owner stays for the audit
     trail, lease-until is removed) and display name '<id> (disabled)'.
A human then runs terraform destroy against the project and 'sandbox reset'.

Runs as the dedicated 'sandbox pool sweeper' static SA (folder editor), so it
needs no Vault involvement and no human in the loop.
"""

import os
import json

from datetime import datetime, timezone

import google.auth
import requests
from google.auth.transport import requests as google_requests

CRM_V1 = "https://cloudresourcemanager.googleapis.com/v1"
SERVICEUSAGE_V1 = "https://serviceusage.googleapis.com/v1"

FOLDER_ID = os.environ.get("FOLDER_ID", "")


def _auth_headers():
    credentials, _ = google.auth.default()
    credentials.refresh(google_requests.Request())
    return {"Authorization": f"Bearer {credentials.token}"}


def _get(url, headers):
    res = requests.get(url, headers=headers, timeout=30)
    res.raise_for_status()
    return res.json()


def _patch_project(project_id, body, headers):
    mask = ",".join(body.get("_mask", []))
    payload = {k: v for k, v in body.items() if k != "_mask"}
    url = f"{CRM_V1}/projects/{project_id}?updateMask={mask}"
    res = requests.patch(url, headers=headers, json=payload, timeout=30)
    res.raise_for_status()
    return res.json()


def _disable_all_services(project_id, headers):
    res = _get(f"{SERVICEUSAGE_V1}/projects/{project_id}/services?filter=state:ENABLED", headers)
    service_ids = [
        service["name"].rsplit("/", 1)[-1]
        for service in res.get("services", [])
        if service.get("state") == "ENABLED"
    ]
    if not service_ids:
        return 0
    res = requests.post(
        f"{SERVICEUSAGE_V1}/projects/{project_id}/services:batchDisable",
        headers=headers,
        json={"serviceIds": service_ids},
        timeout=30,
    )
    res.raise_for_status()
    operation = res.json()
    operation_name = operation.get("name", "")
    while operation_name:
        poll = _get(f"{SERVICEUSAGE_V1}/{operation_name.lstrip('/')}", headers)
        if poll.get("done") is True:
            if poll.get("error"):
                raise RuntimeError(poll["error"])
            break
    return len(service_ids)


def _parse_lease_until(value):
    try:
        return datetime.fromisoformat(value)
    except (ValueError, TypeError):
        return None


def sweep_expired(request):
    """HTTP-triggered entry point (functions_framework)."""
    if not FOLDER_ID.isdigit():
        return (f"FOLDER_ID env var missing or invalid: {FOLDER_ID!r}", 500)

    try:
        headers = _auth_headers()
    except Exception as exc:  # noqa: BLE001
        return (f"auth failure: {exc}", 500)

    pool = _get(f"{CRM_V1}/projects?filter=parent.type:folder%20parent.id:{FOLDER_ID}", headers)
    now = datetime.now(timezone.utc)
    released = []
    failures = []

    for project in pool.get("projects", []):
        project_id = project.get("projectId", "")
        labels = project.get("labels") or {}
        if labels.get("state") != "leased":
            continue

        lease_until = _parse_lease_until(labels.get("lease-until"))
        if lease_until is not None and lease_until > now:
            continue

        try:
            disabled_count = _disable_all_services(project_id, headers)
            labels["state"] = "disabled"
            labels.pop("lease-until", None)
            _patch_project(
                project_id,
                {
                    "labels": labels,
                    "displayName": f"{project_id} (disabled)",
                    "_mask": ["labels", "displayName"],
                },
                headers,
            )
            released.append({"projectId": project_id, "servicesDisabled": disabled_count})
        except Exception as exc:  # noqa: BLE001
            failures.append({"projectId": project_id, "error": str(exc)})

    return json.dumps({"released": released, "failures": failures}, indent=2)
