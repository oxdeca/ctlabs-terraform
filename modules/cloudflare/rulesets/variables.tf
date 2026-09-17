# ------------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/rulesets/variables.tf
# ------------------------------------------------------------------------------

variable zone_id {
  description = "The Cloudflare Zone ID where the rulesets will be applied."
  type        = string
}

variable account {
  description = "The Cloudflare Account details"
  type = object({
    id = string
  })
}

variable "rulesets" {
  description = "A map of Cloudflare rulesets keyed by their exact phase name."
  type = map(object({
    kind        = string
    scope       = optional(string, "zone")
    name        = optional(string, "default")
    description = optional(string, "Managed by Terraform")

    rules = list(object({
      ref         = optional(string)
      description = optional(string, "")
      expression  = string
      action      = string
      enabled     = optional(bool, true)
      
      action_parameters = optional(object({
        id       = optional(string)
        bic      = optional(bool)
        cache    = optional(bool)
        phases   = optional(list(string))
        products = optional(list(string))

        from_list = optional(object({
          name = string
          key  = string
        }))

        uri = optional(object({
          path = optional(object({
            expression = optional(string)
            value      = optional(string)
          }))
          query = optional(object({
            expression = optional(string)
            value      = optional(string)
          }))
        }))

        headers = optional(map(object({
          operation  = string
          expression = optional(string)
          value      = optional(string)
        })))

        origin = optional(object({
          host = optional(string)
          port = optional(number)
        }))

        algorithms = optional(list(string))

        content      = optional(string)
        content_type = optional(string)

        cookie_fields   = optional(list(string))
        request_fields  = optional(list(string))
        response_fields = optional(list(string))

        edge_ttl = optional(object({
          mode    = string
          default = optional(number)
        }))

        overrides = optional(object({
          action            = optional(string)
          enabled           = optional(bool)
          sensitivity_level = optional(string)
          categories = optional(list(object({
            category = string
            action   = optional(string)
            enabled  = optional(bool)
          })))
          rules = optional(list(object({
            id                = string
            action            = optional(string)
            enabled           = optional(bool)
            score_threshold   = optional(number)
            sensitivity_level = optional(string)
          })))
        }))

        from_value = optional(object({
          preserve_query_string = optional(bool)
          status_code           = optional(number)
          target_url = optional(object({
            expression = optional(string)
            value      = optional(string)
          }))
        }))
      }))

      ratelimit = optional(object({
        characteristics     = optional(list(string))
        requests_to_origin  = optional(bool)
        mitigation_timeout  = optional(number)
        period              = optional(number)
        requests_per_period = optional(number)
      }))

      logging = optional(object({
        enabled = bool
      }))
    }))
  }))
}
