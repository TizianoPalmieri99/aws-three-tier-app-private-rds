# Where the logs land, and where a notification goes.

# --- CloudWatch Logs --------------------------------------------------------

# The CloudWatch Agent would create these groups itself on first write, but
# then their retention would be "never expire" and the logs would keep costing
# after the lab is gone. Declaring them here fixes the retention up front and
# means `terraform destroy` removes them too.
resource "aws_cloudwatch_log_group" "apache_access" {
  name              = "/${var.name_prefix}/apache/access"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/${var.name_prefix}/apache/access"
  }
}

resource "aws_cloudwatch_log_group" "apache_error" {
  name              = "/${var.name_prefix}/apache/error"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/${var.name_prefix}/apache/error"
  }
}

# --- Alerting ---------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = {
    Name = "${var.name_prefix}-alerts"
  }
}

# Created only if an address is passed in, so no email ends up in the
# repository. The subscription stays "pending confirmation" until the link in
# the confirmation email is clicked; an unconfirmed subscription receives
# nothing.
resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
