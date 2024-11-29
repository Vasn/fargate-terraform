# load balancer
resource "aws_lb" "main" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  enable_deletion_protection = false
  security_groups            = var.alb_security_groups
  subnets                    = var.alb_subnets

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# target group - web
resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-ecs-web"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    path                = "/"
    matcher             = 200
    healthy_threshold   = 10
    unhealthy_threshold = 10
    interval            = 300 # in seconds
    timeout             = 120 # in seconds
  }
}

# target group - app
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-ecs-app"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    path                = "/"
    matcher             = 200
    healthy_threshold   = 10
    unhealthy_threshold = 10
    interval            = 300 # in seconds
    timeout             = 120 # in seconds
  }
}

# acm - ssl certificate
resource "aws_acm_certificate" "web_app" {
  domain_name       = var.web_domain
  validation_method = "DNS"
  subject_alternative_names = [
    var.app_domain
  ]

  tags = {
    Name = "${var.project_name}-alb-ssl"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# azure - cname validation records
resource "azurerm_dns_cname_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.web_app.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
    }
  }

  name                = replace(each.value.name, ".swiftoffice.org.", "")
  zone_name           = var.azure_dns_zone_name
  resource_group_name = var.azure_resource_group_name
  ttl                 = var.azure_cname_ttl
  record              = each.value.value
}

# azure - web and api cname records
resource "azurerm_dns_cname_record" "web" {
  name                = replace(var.web_domain, ".swiftoffice.org", "")
  zone_name           = var.azure_dns_zone_name
  resource_group_name = var.azure_resource_group_name
  ttl                 = var.azure_cname_ttl
  record              = aws_lb.main.dns_name
}

resource "azurerm_dns_cname_record" "app" {
  name                = replace(var.app_domain, ".swiftoffice.org", "")
  zone_name           = var.azure_dns_zone_name
  resource_group_name = var.azure_resource_group_name
  ttl                 = var.azure_cname_ttl
  record              = aws_lb.main.dns_name
}

# acm - validation
resource "aws_acm_certificate_validation" "cert_validate" {
  certificate_arn = aws_acm_certificate.web_app.arn
  validation_record_fqdns = [
    for cname in azurerm_dns_cname_record.validation : cname.fqdn
  ]
}

# listener - http (80) redirect to https (443)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# listener - https (443) forward to target groups based on domain routing (header)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validate.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    host_header {
      values = [var.web_domain]
    }
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    host_header {
      values = [var.app_domain]
    }
  }
}

# WAF (attached to ALB)
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-managed-rule"
  description = "Managed rule"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule { # rate limit 500 request per 5 minutes originating from a single IP
    name     = "rate-limit-rule"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = 500
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.project_name}-rate-limit-rule-metric"
      sampled_requests_enabled   = true
    }
  }

  rule { # bot protection
    name     = "bot-control-rule"
    priority = 11

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.project_name}-bot-control-rule-metric"
      sampled_requests_enabled   = true
    }
  }

  rule { # core common threat protection
    name     = "core-rule"
    priority = 12

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.project_name}-core-rule-metric"
      sampled_requests_enabled   = true
    }
  }

  rule { # geo blocking countries using rule group reference
    name     = "block-countries-rule"
    priority = 13

    override_action {
      none {}
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.main.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.project_name}-geo-blocking-rule-metric"
      sampled_requests_enabled   = true
    }
  }

  captcha_config {
    immunity_time_property {
      immunity_time = 300 // default 300s
    }
  }

  challenge_config {
    immunity_time_property {
      immunity_time = 300 // default 300s
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.project_name}-alb-acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_rule_group" "main" {
  name     = "block-countries-rule-group"
  capacity = 1
  scope    = "REGIONAL"

  rule {
    name     = "exclude-countries"
    priority = 10

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = ["MY"]
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "exclude-countries-metric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "block-countries-rule-group-metric"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}