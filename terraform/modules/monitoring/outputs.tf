output "sns_topic_arn" {
  description = "ARN of the SNS topic the CPU alarm publishes to."
  value       = aws_sns_topic.alerts.arn
}

output "log_group_names" {
  description = "CloudWatch log groups the CloudWatch Agent writes the Apache logs to."
  value = [
    aws_cloudwatch_log_group.apache_access.name,
    aws_cloudwatch_log_group.apache_error.name,
  ]
}

output "cpu_alarm_name" {
  description = "Name of the CPU alarm."
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}
