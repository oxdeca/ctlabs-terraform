#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/scripts/gcp_wif_setup.py
# Purpose : Automates the "One-time GCP Setup" steps in
#           ctlabs/docs/ctlabs.docs.vault.gcp.wif.md for GCP Workload Identity
#           Federation. Run this wherever `gcloud` is installed and already
#           authenticated (`gcloud auth login`) with IAM Admin on the target
#           project - designed for the operator's own desktop, not the
#           ctlabs box (ctlabs's runtime path never needs gcloud/SDK).
#
#           Safe to re-run: every step checks for an existing resource first.
#           Re-running with a fresh --jwks-file (from vault_oidc_setup.py) is
#           also how you push a rotated Vault signing key to the provider.
#
#           Pass --cleanup to tear down instead. By default cleanup only
#           removes the WIF impersonation binding(s) for --subject - the
#           pool/provider/service-account/project-roles are left alone since
#           they may be shared with other things. Opt into removing those too
#           with --delete-provider / --delete-pool / --delete-service-account
#           / --remove-sa-roles.
# -----------------------------------------------------------------------------
import argparse
import subprocess
import sys


def run_gcloud(args, check=True):
    result = subprocess.run(["gcloud"] + args + ["--quiet"], capture_output=True, text=True)
    if check and result.returncode != 0:
        sys.exit(f"gcloud {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result


def exists(describe_args):
    return run_gcloud(describe_args, check=False).returncode == 0


def confirm(prompt, assume_yes):
    if assume_yes:
        return True
    return input(f"{prompt} [y/N] ").strip().lower() == "y"


def sa_email_for(args):
    return f"{args.service_account_id}@{args.project}.iam.gserviceaccount.com"


def project_number_for(args):
    return run_gcloud(["projects", "describe", args.project, "--format=value(projectNumber)"]).stdout.strip()


def setup(args):
    sa_roles = args.sa_role or ["roles/editor"]

    print("0. Enabling required APIs")
    run_gcloud([
        "services", "enable", "iam.googleapis.com", "sts.googleapis.com",
        "iamcredentials.googleapis.com", "--project", args.project,
    ])

    print(f"1. Workload Identity Pool '{args.pool_id}'")
    if exists([
        "iam", "workload-identity-pools", "describe", args.pool_id,
        "--project", args.project, "--location=global",
    ]):
        print("   already exists, skipping")
    else:
        run_gcloud([
            "iam", "workload-identity-pools", "create", args.pool_id,
            "--project", args.project, "--location=global",
            "--display-name=CTLabs Vault OIDC Pool",
        ])

    print(f"2. OIDC provider '{args.provider_id}'")
    provider_exists = exists([
        "iam", "workload-identity-pools", "providers", "describe", args.provider_id,
        "--project", args.project, "--workload-identity-pool", args.pool_id, "--location=global",
    ])
    provider_cmd = [
        "iam", "workload-identity-pools", "providers",
        "update-oidc" if provider_exists else "create-oidc", args.provider_id,
        "--project", args.project, "--workload-identity-pool", args.pool_id, "--location=global",
    ]
    if not provider_exists:
        provider_cmd += [f"--issuer-uri={args.issuer}", f"--attribute-mapping={args.attribute_mapping}"]
    if args.jwks_file:
        provider_cmd += [f"--jwk-json-path={args.jwks_file}"]
    run_gcloud(provider_cmd)
    if provider_exists and args.jwks_file:
        print("   pushed fresh JWKS (key rotation)")

    sa_email = sa_email_for(args)
    print(f"3. Service account '{sa_email}'")
    if exists(["iam", "service-accounts", "describe", sa_email, "--project", args.project]):
        print("   already exists, skipping")
    else:
        run_gcloud([
            "iam", "service-accounts", "create", args.service_account_id,
            "--project", args.project, "--display-name=Terraform Runner (WIF)",
        ])

    print(f"4. Granting {sa_roles} on the project to {sa_email}")
    for role in sa_roles:
        run_gcloud([
            "projects", "add-iam-policy-binding", args.project,
            f"--member=serviceAccount:{sa_email}", f"--role={role}", "--condition=None",
        ])

    project_number = project_number_for(args)

    print(f"5. Granting WIF impersonation for {len(args.subject)} subject(s)")
    for subject in args.subject:
        member = (
            f"principal://iam.googleapis.com/projects/{project_number}"
            f"/locations/global/workloadIdentityPools/{args.pool_id}/subject/{subject}"
        )
        run_gcloud([
            "iam", "service-accounts", "add-iam-policy-binding", sa_email,
            "--project", args.project, "--role=roles/iam.workloadIdentityUser",
            f"--member={member}", "--condition=None",
        ])

    audience = (
        f"//iam.googleapis.com/projects/{project_number}/locations/global/"
        f"workloadIdentityPools/{args.pool_id}/providers/{args.provider_id}"
    )
    print("\nDone. ctlabs Terraform editor values:")
    print(f"  WIF Provider Audience : {audience}")
    print(f"  Impersonated SA       : {sa_email}")
    print("  Vault OIDC Role       : whatever --role-name you gave vault_oidc_setup.py")


def cleanup(args):
    sa_email = sa_email_for(args)
    sa_roles = args.sa_role or ["roles/editor"]

    print("This will remove:")
    print(f"  WIF impersonation binding(s) for {len(args.subject)} subject(s) on {sa_email}")
    if args.remove_sa_roles:
        print(f"  Project-level role(s) {sa_roles} from {sa_email}")
    if args.delete_provider:
        print(f"  OIDC provider '{args.provider_id}'")
    if args.delete_pool:
        print(f"  Workload Identity Pool '{args.pool_id}' (GCP soft-deletes this for 30 days)")
    if args.delete_service_account:
        print(f"  Service account '{sa_email}'")
    if not confirm("Proceed?", args.yes):
        sys.exit("Aborted.")

    project_number = project_number_for(args)

    print(f"1. Removing WIF impersonation for {len(args.subject)} subject(s)")
    for subject in args.subject:
        member = (
            f"principal://iam.googleapis.com/projects/{project_number}"
            f"/locations/global/workloadIdentityPools/{args.pool_id}/subject/{subject}"
        )
        result = run_gcloud([
            "iam", "service-accounts", "remove-iam-policy-binding", sa_email,
            "--project", args.project, "--role=roles/iam.workloadIdentityUser",
            f"--member={member}",
        ], check=False)
        print("   done" if result.returncode == 0 else f"   skipped: {result.stderr.strip()}")

    if args.remove_sa_roles:
        print(f"2. Removing {sa_roles} from {sa_email}")
        for role in sa_roles:
            result = run_gcloud([
                "projects", "remove-iam-policy-binding", args.project,
                f"--member=serviceAccount:{sa_email}", f"--role={role}",
            ], check=False)
            print("   done" if result.returncode == 0 else f"   skipped: {result.stderr.strip()}")

    if args.delete_provider:
        print(f"3. Deleting OIDC provider '{args.provider_id}'")
        run_gcloud([
            "iam", "workload-identity-pools", "providers", "delete", args.provider_id,
            "--project", args.project, "--workload-identity-pool", args.pool_id, "--location=global",
        ])

    if args.delete_pool:
        print(f"4. Deleting Workload Identity Pool '{args.pool_id}'")
        run_gcloud([
            "iam", "workload-identity-pools", "delete", args.pool_id,
            "--project", args.project, "--location=global",
        ])

    if args.delete_service_account:
        print(f"5. Deleting service account '{sa_email}'")
        run_gcloud(["iam", "service-accounts", "delete", sa_email, "--project", args.project])

    print("\nDone.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True)
    parser.add_argument("--pool-id", default="ctlabs-vault-pool")
    parser.add_argument("--provider-id", default="vault-provider")
    parser.add_argument("--issuer", help=(
        "The real 'iss' claim vault_oidc_setup.py printed (includes the "
        "'/v1/identity/oidc' suffix Vault appends) - NOT the bare address "
        "you passed to --vault-addr / identity/oidc/config issuer. Required "
        "unless --cleanup."
    ))
    parser.add_argument("--jwks-file", default=None, help="JWKS from vault_oidc_setup.py; omit to use discovery instead")
    parser.add_argument("--attribute-mapping", default="google.subject=assertion.sub")
    parser.add_argument("--service-account-id", default="terraform-runner")
    parser.add_argument("--sa-role", action="append", default=None,
                         help="IAM role to grant the SA on the project (repeatable, default roles/editor)")
    parser.add_argument("--subject", action="append", required=True,
                         help="Vault 'sub' claim value to bind (repeatable - printed by vault_oidc_setup.py)")
    parser.add_argument("--cleanup", action="store_true", help="Tear down instead of creating/updating")
    parser.add_argument("--yes", action="store_true", help="With --cleanup, skip the confirmation prompt")
    parser.add_argument("--delete-provider", action="store_true", help="With --cleanup, also delete the OIDC provider")
    parser.add_argument("--delete-pool", action="store_true", help="With --cleanup, also delete the pool (30-day soft-delete)")
    parser.add_argument("--delete-service-account", action="store_true", help="With --cleanup, also delete the service account")
    parser.add_argument("--remove-sa-roles", action="store_true", help="With --cleanup, also remove --sa-role grant(s) from the project")
    args = parser.parse_args()

    if args.cleanup:
        cleanup(args)
    else:
        if not args.issuer:
            sys.exit("--issuer is required (unless --cleanup)")
        setup(args)


if __name__ == "__main__":
    main()
