# Observability: log groups, the CPU alarm and the SNS topic it publishes to.

# --- CloudWatch Logs --------------------------------------------------------

# The CloudWatch Agent would create these groups itself on first write, but
# then their retention would be "never expire" and the logs would keep costing
# after the lab is gone. Declaring them here fixes the retention up front and
# means `terraform destroy` removes them too.
resource "aws_cloudwatch_log_group" "apache_access" {
  name              = "/${var.project_name}/apache/access"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/${var.project_name}/apache/access"
  }
}

resource "aws_cloudwatch_log_group" "apache_error" {
  name              = "/${var.project_name}/apache/error"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/${var.project_name}/apache/error"
  }
}

# --- Alerting ---------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name = "${var.project_name}-alerts"
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

# --- Alarm ------------------------------------------------------------------

# Average CPU across the Auto Scaling group. The dimension is the name of the
# group, which is why the group is named by Terraform rather than by hand.
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "${var.project_name}-high-cpu"
  alarm_description = "Average CPU utilisation of the application tier above ${var.cpu_alarm_threshold}%"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  period      = 300 # 5 minutes, the resolution of the standard EC2 metric

  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_alarm_threshold
  evaluation_periods  = 1

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  # Missing data is not a problem here: it means no instance is reporting, and
  # treating that as a breach would page for nothing.
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-high-cpu"
  }
}
