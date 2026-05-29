# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "new_relic_account_id" {
  description = "New Relic account ID"
  type        = number
}

variable "new_relic_license_key" {
  description = "New Relic ingest license key passed to Lambda as NEW_RELIC_LICENSE_KEY"
  type        = string
  sensitive   = true
}

variable "new_relic_api_key" {
  description = "New Relic User API key used by the Terraform provider for NerdGraph"
  type        = string
  sensitive   = true
}

variable "nr_python312_arm64_layer_version" {
  description = "New Relic Python 3.12 ARM64 layer version. See https://layers.newrelic-external.com/"
  type        = number
  default     = 119
}

variable "nr_extension_arm64_layer_version" {
  description = "New Relic Lambda Extension ARM64 layer version. See https://layers.newrelic-external.com/"
  type        = number
  default     = 71
}

variable "new_relic_region" {
  description = "New Relic data center region: US or EU. Check NR UI — if your URL is one.eu.newrelic.com it's EU, otherwise US."
  type        = string
  default     = "US"
}

# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------

provider "newrelic" {
  account_id = var.new_relic_account_id
  api_key    = var.new_relic_api_key
  region     = var.new_relic_region
}

# ---------------------------------------------------------------------------
# Layer ARNs — published publicly by New Relic (AWS account 451483290750).
# Check https://layers.newrelic-external.com/ for newer versions.
# ---------------------------------------------------------------------------

locals {
  nr_python312_arm64_layer = "arn:aws:lambda:${var.aws_region}:451483290750:layer:NewRelicPython312ARM64:${var.nr_python312_arm64_layer_version}"
  nr_extension_arm64_layer = "arn:aws:lambda:${var.aws_region}:451483290750:layer:NewRelicLambdaExtensionARM64:${var.nr_extension_arm64_layer_version}"
}

# ---------------------------------------------------------------------------
# Alerts
# ---------------------------------------------------------------------------

resource "newrelic_alert_policy" "main" {
  name                = "${var.app_name}-alerts"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

resource "newrelic_nrql_alert_condition" "chat_error_rate" {
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "ai-o11y-chat: Error Rate > 5%"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = 'ai-o11y-chat'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "chat_p95_duration" {
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "ai-o11y-chat: P95 Duration > 30s"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentile(duration, 95) FROM Transaction WHERE appName = 'ai-o11y-chat'"
  }

  critical {
    operator              = "above"
    threshold             = 30
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "above"
    threshold             = 15
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "graphql_error_rate" {
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "ai-o11y-graphql: Error Rate > 5%"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = 'ai-o11y-graphql'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

resource "newrelic_one_dashboard" "main" {
  name        = "AI O11y Demo"
  permissions = "public_read_only"

  page {
    name = "Overview"

    widget_markdown {
      title  = ""
      row    = 1
      column = 1
      width  = 12
      height = 1
      text   = "# AI O11y Demo — Car Companion Chatbot\nai-o11y-chat (Python + Bedrock) · ai-o11y-graphql (Go)"
    }

    widget_line {
      title  = "Invocations / min"
      row    = 2
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT rate(count(*), 1 minute) FROM Transaction WHERE appName IN ('ai-o11y-chat', 'ai-o11y-graphql') FACET appName TIMESERIES AUTO"
      }
    }

    widget_line {
      title  = "Error Rate (%)"
      row    = 2
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName IN ('ai-o11y-chat', 'ai-o11y-graphql') FACET appName TIMESERIES AUTO"
      }
    }

    widget_line {
      title  = "Chat Response Time — P50 / P95 / P99 (s)"
      row    = 5
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT percentile(duration, 50, 95, 99) FROM Transaction WHERE appName = 'ai-o11y-chat' TIMESERIES AUTO"
      }
    }

    widget_line {
      title  = "GraphQL Response Time — P50 / P95 (s)"
      row    = 5
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT percentile(duration, 50, 95) FROM Transaction WHERE appName = 'ai-o11y-graphql' TIMESERIES AUTO"
      }
    }

    widget_billboard {
      title  = "Chat Invocations (1h)"
      row    = 8
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM Transaction WHERE appName = 'ai-o11y-chat' SINCE 1 hour ago"
      }
    }

    widget_billboard {
      title  = "Chat Errors (1h)"
      row    = 8
      column = 5
      width  = 4
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM TransactionError WHERE appName = 'ai-o11y-chat' SINCE 1 hour ago"
      }

      critical = 10
      warning  = 5
    }

    widget_billboard {
      title  = "Chat Avg Duration (1h)"
      row    = 8
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(duration) FROM Transaction WHERE appName = 'ai-o11y-chat' SINCE 1 hour ago"
      }

      critical = 30
      warning  = 15
    }
  }
}
