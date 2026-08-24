variable "name_prefix" {
  description = "Prefix used to name the load balancer and the target group."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the target group belongs to."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets the load balancer places a node in, one per Availability Zone."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the load balancer."
  type        = string
}

variable "health_check_path" {
  description = "Path the target group requests to decide whether a target is healthy."
  type        = string
  default     = "/"
}

variable "deregistration_delay" {
  description = "Seconds a target keeps serving in-flight requests after it is deregistered."
  type        = number
  default     = 30
}
