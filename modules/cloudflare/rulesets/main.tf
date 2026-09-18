# ------------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/rulesets/main.tf
# ------------------------------------------------------------------------------

resource "cloudflare_ruleset" "ruleset" {
  for_each = var.rulesets

  phase       = each.key
  zone_id     = try(each.value.scope == "zone" ? var.zone_id : null, var.zone_id)
  account_id  = try(each.value.scope == "account" ? var.account.id : null, null)
  kind        = each.value.kind  # "zone" = "L7", "root" = "L3/4"
  name        = each.value.name
  description = each.value.description

  rules = [
    for r in each.value.rules : {
      ref         = r.ref
      description = r.description
      expression  = r.expression
      action      = r.action
      enabled     = r.enabled

      # Map action_parameters strictly to avoid passing null blocks where unneeded
      action_parameters = r.action_parameters != null ? {
        id       = r.action_parameters.id
        bic      = r.action_parameters.bic
        cache    = r.action_parameters.cache
        phases   = r.action_parameters.phases
        products = r.action_parameters.products

        from_list       = r.action_parameters.from_list
        uri             = r.action_parameters.uri
        headers         = r.action_parameters.headers
        origin          = r.action_parameters.origin
        algorithms      = r.action_parameters.algorithms != null ? [for a in r.action_parameters.algorithms : {name = a }] : null
        content         = r.action_parameters.content
        content_type    = r.action_parameters.content_type
        cookie_fields   = r.action_parameters.cookie_fields   != null ? [for f in r.action_parameters.cookie_fields   : { name = f }] : null
        request_fields  = r.action_parameters.request_fields  != null ? [for f in r.action_parameters.request_fields  : { name = f }] : null
        response_fields = r.action_parameters.response_fields != null ? [for f in r.action_parameters.response_fields : { name = f }] : null

        overrides = r.action_parameters.overrides != null ? {
          action            = r.action_parameters.overrides.action
          enabled           = r.action_parameters.overrides.enabled
          sensitivity_level = r.action_parameters.overrides.sensitivity_level

          categories = r.action_parameters.overrides.categories != null ? [
            for c in r.action_parameters.overrides.categories : {
              category = c.category
              action   = c.action
              enabled  = c.enabled
            }
          ] : null

          rules = r.action_parameters.overrides.rules != null ? [
            for rule in r.action_parameters.overrides.rules : {
              id                = rule.id
              action            = rule.action
              enabled           = rule.enabled
              score_threshold   = rule.score_threshold
              sensitivity_level = rule.sensitivity_level
            }
          ] : null
        } : null

        from_value = r.action_parameters.from_value != null ? {
          preserve_query_string = r.action_parameters.from_value.preserve_query_string
          status_code           = r.action_parameters.from_value.status_code
          target_url = r.action_parameters.from_value.target_url != null ? {
            expression = r.action_parameters.from_value.target_url.expression
            value      = r.action_parameters.from_value.target_url.value
          } : null
        } : null
      } : null

      rate_limit = r.ratelimit != null ? {
        characteristics     = r.ratelimit.characteristics
        requests_to_origin  = r.ratelimit.requests_to_origin
        mitigation_timeout  = r.ratelimit.mitigation_timeout
        period              = r.ratelimit.period
        requests_per_period = r.ratelimit.requests_per_period
      } : null

      logging = r.logging != null ? {
        enabled = r.logging.enabled
      } : null
    }
  ]
}
