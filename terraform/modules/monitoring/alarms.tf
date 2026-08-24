# Average CPU across the Auto Scaling group.
#
# The dimension is the name of the group, read from the compute module rather
# than typed in. An alarm pointed at a group name that no longer exists does
# not fail: it sits in INSUFFICIENT_DATA and quietly watches nothing, which is
# worse than failing.

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "${var.name_prefix}-high-cpu"
  alarm_description = "Average CPU utilisation of the application tier above ${var.cpu_alarm_threshold}%"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  period      = 300 # 5 minutes, the resolution of the standard EC2 metric

  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_alarm_threshold
  evaluation_periods  = var.cpu_alarm_evaluation_periods

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  # Missing data is not a problem here: it means no instance is reporting, and
  # treating that as a breach would page for nothing.
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.name_prefix}-high-cpu"
  }
}
