variable "name_prefix" {
  description = "Prefix used to name the launch template and the Auto Scaling group."
  type        = string
}

variable "app_subnet_ids" {
  description = "Private application subnets the Auto Scaling group launches instances into."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to every instance."
  type        = string
}

variable "instance_profile_name" {
  description = "Instance profile that delivers the IAM role to the instances."
  type        = string
}

variable "target_group_arn" {
  description = "Target group the Auto Scaling group registers its instances with."
  type        = string
}

variable "user_data_path" {
  description = "Path to the bootstrap script, passed in by the environment because it lives outside the terraform directory."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type used by the launch template."
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances. Two keeps one instance per Availability Zone."
  type        = number
}

variable "desired_capacity" {
  description = "Number of instances the group aims to keep running."
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances the group is allowed to reach."
  type        = number
}

variable "health_check_grace_period" {
  description = "Seconds the group waits before acting on the load balancer health check of a new instance."
  type        = number
  default     = 300
}

variable "common_tags" {
  description = "Tags merged into the launch template tag_specifications, because provider default_tags do not reach instances the Auto Scaling group creates."
  type        = map(string)
  default     = {}
}
