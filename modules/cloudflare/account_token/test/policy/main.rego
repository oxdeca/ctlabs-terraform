package main

# Deny the creation or update of fragile User API Tokens
deny contains msg if {
  some resource in input.resource_changes
  resource.type == "cloudflare_api_token"

  # Only trigger if they are trying to create or update it (allow deletions!)
  some action in resource.change.actions
  action in ["create", "update"]

  msg := sprintf(
    "Security Violation: '%v' uses the 'cloudflare_api_token' resource. Enterprise standards require using 'cloudflare_account_token' for CI/CD durability.",
    [resource.address]
  )
}
