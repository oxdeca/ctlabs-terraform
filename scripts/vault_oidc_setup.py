#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/scripts/vault_oidc_setup.py
# Purpose : Automates the "One-time Vault Setup" steps in
#           ctlabs/docs/ctlabs.docs.vault.gcp.wif.md for GCP Workload Identity
#           Federation. Run this where the `vault` CLI is installed and
#           already authenticated (e.g. inside the ansible/ctrl container) -
#           it never touches GCP itself, only Vault's identity/oidc engine.
#
#           Safe to re-run: every `vault write` here is a full idempotent
#           upsert of the same fields. Pass --cleanup to tear down what this
#           script created instead.
# -----------------------------------------------------------------------------
import argparse
import base64
import json
import os
import ssl
import subprocess
import sys
import urllib.request


def run_vault(args, env, check=True):
    result = subprocess.run(["vault"] + args, capture_output=True, text=True, env=env)
    if check and result.returncode != 0:
        sys.exit(f"vault {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result


def decode_jwt_claims(token):
    payload_b64 = token.split(".")[1]
    padded = payload_b64 + "=" * (-len(payload_b64) % 4)
    return json.loads(base64.urlsafe_b64decode(padded))


def fetch_jwks(vault_addr, insecure):
    ctx = ssl._create_unverified_context() if insecure else None
    url = f"{vault_addr.rstrip('/')}/v1/identity/oidc/.well-known/keys"
    with urllib.request.urlopen(url, context=ctx, timeout=10) as resp:
        return resp.read()


def confirm(prompt, assume_yes):
    if assume_yes:
        return True
    return input(f"{prompt} [y/N] ").strip().lower() == "y"


def build_env(args):
    env = os.environ.copy()
    if args.vault_addr:
        env["VAULT_ADDR"] = args.vault_addr
    insecure = args.insecure or env.get("VAULT_SKIP_VERIFY", "").strip().lower() in ("1", "true", "yes")
    if insecure:
        env["VAULT_SKIP_VERIFY"] = "true"

    if not env.get("VAULT_ADDR"):
        sys.exit("VAULT_ADDR not set - pass --vault-addr or export it first")
    if "VAULT_TOKEN" not in env:
        sys.exit("VAULT_TOKEN not set - run `vault login` first (or export VAULT_TOKEN)")
    return env, insecure


def setup(args):
    env, insecure = build_env(args)
    vault_addr = env["VAULT_ADDR"]

    print(f"1. Pinning OIDC issuer to {args.issuer}")
    run_vault(["write", "identity/oidc/config", f"issuer={args.issuer}"], env)

    print(f"2. Ensuring signing key '{args.key_name}'")
    run_vault([
        "write", f"identity/oidc/key/{args.key_name}",
        "allowed_client_ids=*",
        f"rotation_period={args.rotation_period}",
        f"verification_ttl={args.verification_ttl}",
    ], env)

    print(f"3. Ensuring role '{args.role_name}' (client_id={args.client_id})")
    role_args = [
        "write", f"identity/oidc/role/{args.role_name}",
        f"key={args.key_name}", f"ttl={args.token_ttl}", f"client_id={args.client_id}",
    ]
    run_vault(role_args, env)

    print("4. Reading a test token to confirm claims")
    token_json = run_vault(["read", "-format=json", f"identity/oidc/token/{args.role_name}"], env).stdout
    token = json.loads(token_json)["data"]["token"]
    claims = decode_jwt_claims(token)
    print(json.dumps(claims, indent=2))
    print(f"\n>>> sub claim (bind this in the GCP IAM policy): {claims['sub']}")
    print(
        f">>> real iss claim (use this, not --issuer, for gcp_wif_setup.py --issuer - "
        f"Vault appends '/v1/identity/oidc' to whatever you pin): {claims['iss']}"
    )

    print(f"\n5. Fetching JWKS -> {args.jwks_out}")
    with open(args.jwks_out, "wb") as f:
        f.write(fetch_jwks(vault_addr, insecure))

    print(
        "\nDone. On the GCP side, run (same --pool-id/--provider-id as used above):\n"
        f"  gcp_wif_setup.py --issuer {claims['iss']} --jwks-file {args.jwks_out} "
        f"--subject {claims['sub']} --pool-id {args.pool_id} --provider-id {args.provider_id} "
        f"--project <your-project>"
    )


def cleanup(args):
    env, _ = build_env(args)

    print(f"This will delete:\n  identity/oidc/role/{args.role_name}\n  identity/oidc/key/{args.key_name}")
    if args.reset_issuer:
        print("  and reset identity/oidc/config issuer to Vault's default (cluster api_addr)")
    if not confirm("Proceed?", args.yes):
        sys.exit("Aborted.")

    print(f"1. Deleting role '{args.role_name}' (must go before the key - Vault won't delete a key still in use)")
    result = run_vault(["delete", f"identity/oidc/role/{args.role_name}"], env, check=False)
    print("   done" if result.returncode == 0 else f"   skipped: {result.stderr.strip()}")

    print(f"2. Deleting key '{args.key_name}'")
    result = run_vault(["delete", f"identity/oidc/key/{args.key_name}"], env, check=False)
    print("   done" if result.returncode == 0 else f"   skipped: {result.stderr.strip()}")

    if args.reset_issuer:
        print("3. Resetting identity/oidc/config issuer to default")
        run_vault(["write", "identity/oidc/config", "issuer="], env)
    else:
        print("3. Leaving identity/oidc/config issuer as-is (pass --reset-issuer to clear it - "
              "it's a global setting other roles may depend on)")

    print("\nDone.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vault-addr", default=None, help="Defaults to $VAULT_ADDR")
    parser.add_argument("--issuer", help="e.g. https://vdb1.ctlabs.internal:8200 (required unless --cleanup)")
    parser.add_argument("--key-name", default="gcp-wif-key")
    parser.add_argument("--role-name", default="gcp-wif")
    parser.add_argument("--client-id", default=None, help=(
        "Full GCP WIF provider audience string to use as-is, e.g. "
        "'//iam.googleapis.com/projects/<num>/locations/global/workloadIdentityPools/<pool>/providers/<provider>'. "
        "Prefer --project-number instead (below) unless you already have this exact string - "
        "it's easy to paste net01's/another host's audience by mistake."
    ))
    parser.add_argument("--project-number", default=None, help=(
        "GCP project number (NOT project ID) - look it up any time with "
        "`gcloud projects describe <project> --format='value(projectNumber)'`, no pool/provider "
        "need to exist yet. Combined with --pool-id/--provider-id to build the audience string "
        "automatically, so this script alone can set client_id correctly on the first run - no "
        "second pass needed once gcp_wif_setup.py has created the pool/provider."
    ))
    parser.add_argument("--pool-id", default="ctlabs-vault-pool", help="Must match gcp_wif_setup.py's --pool-id")
    parser.add_argument("--provider-id", default="vault-provider", help="Must match gcp_wif_setup.py's --provider-id")
    parser.add_argument("--rotation-period", default="24h")
    parser.add_argument("--verification-ttl", default="24h")
    parser.add_argument("--token-ttl", default="10m")
    parser.add_argument("--jwks-out", default="vault-jwks.json")
    parser.add_argument("--insecure", action="store_true", help="Skip TLS verification (self-signed Vault cert)")
    parser.add_argument("--cleanup", action="store_true", help="Tear down the role + key instead of creating them")
    parser.add_argument("--reset-issuer", action="store_true", help="With --cleanup, also clear identity/oidc/config issuer")
    parser.add_argument("--yes", action="store_true", help="With --cleanup, skip the confirmation prompt")
    args = parser.parse_args()

    if args.cleanup:
        cleanup(args)
    else:
        if not args.issuer:
            sys.exit("--issuer is required (unless --cleanup)")
        if not args.client_id:
            if not args.project_number:
                sys.exit(
                    "Must pass --client-id (a full audience string) or --project-number "
                    "(+ optional --pool-id/--provider-id) so client_id can be set correctly. "
                    "A role with no client_id gets Vault's auto-generated random one, which GCP "
                    "always rejects as an audience mismatch - this is not optional."
                )
            args.client_id = (
                f"//iam.googleapis.com/projects/{args.project_number}/locations/global/"
                f"workloadIdentityPools/{args.pool_id}/providers/{args.provider_id}"
            )
        setup(args)


if __name__ == "__main__":
    main()
