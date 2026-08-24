variable "name_prefix" {
  description = "Prefix used to name the log groups, the topic and the alarm."
  type        = string
}

variable "autoscaling_group_name" {
  description = "Auto Scaling group the CPU alarm watches. It is the dimension of the metric."
  type        = string
}

variable "log_retention_days" {
  description = "Retention of the Apache log groups in CloudWatch Logs."
  type        = number
  default     = 7
}

variable "alert_email" {
  description = "Address subscribed to the SNS topic. Empty means no subscription is created, which is the safe default for a public repository."
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "Average CPU utilisation percentage above which the alarm fires."
  type        = number
  default     = 70
}

variable "cpu_alarm_evaluation_periods" {
  description = "How many consecutive periods have to breach before the alarm fires."
  type        = number
  default     = 1
}
