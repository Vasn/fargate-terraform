resource "aws_networkfirewall_rule_group" "main" {
  capacity = 100
  name     = "${var.project_name}-networkfirewall-rulegroup"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["TLS_SNI"]
        targets              = [".amazonaws.com", "login.microsoftonline.com", ".swiftoffice.org"]
      }
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.project_name}-networkfirewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.main.arn
    }
    # The ARN of the TLS inspection policy to attach to this FW policy. Can only be added on policy creation.
    # tls_inspection_configuration_arn = aws_networkfirewall_tls_inspection_configuration.main.arn
  }
}

resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.project_name}-networkfirewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = var.vpc_id

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnet_ids

    content {
      subnet_id = subnet_mapping.value
    }
  }

  delete_protection                 = false # default
  firewall_policy_change_protection = false # default
  subnet_change_protection          = false # default

  timeouts {
    create = "30m" # default
    update = "30m" # default
    delete = "30m" # default
  }
}

# Apparently, TLS is a new log type which is added to network firewall and the aws provider has "hardcoded" for there to only be 2 types so you could only have two types of logs for now: https://github.com/hashicorp/terraform-provider-aws/issues/38917


resource "aws_cloudwatch_log_group" "firewall_alert" {
  name = "${var.project_name}-networkfirewall-alert"
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  name = "${var.project_name}-networkfirewall-flow"
}

# resource "aws_cloudwatch_log_group" "firewall_tls" {
#   name = "${var.project_name}-networkfirewall-tls"
# }

resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn
  logging_configuration {
    log_destination_config {
      log_destination = {
        "logGroup" = aws_cloudwatch_log_group.firewall_alert.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        "logGroup" = aws_cloudwatch_log_group.firewall_flow.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }

    # log_destination_config {
    #   log_destination = {
    #     "logGroup" = aws_cloudwatch_log_group.firewall_tls.name
    #   }
    #   log_destination_type = "CloudWatchLogs"
    #   log_type             = "TLS"
    # }
  }
}


## Steps to do to test
# Create Firewall subnet - DONE
# Configure the route table - DONE
# Re-target your dns to target the firewall instead of the alb
# Re-target firewall to alb
# Deploy all your services
# See your logs and see which resources or domains are blocked by your firewall via your cloudwatch logs
# Unblock those domains used by your application

# FIGURE OUT HOW TO DO THE RULES FOR THE FIREWALL, DROP ALL EXCEPT ALLOW FQDN