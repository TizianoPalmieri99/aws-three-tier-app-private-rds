# Input variables. Every default matches the architecture as it was built by
# hand, so `terraform apply` with no .tfvars file reproduces it.

variable "aws_region" {
  description = "AWS region the whole stack is deployed into."
  type        = string
  default     = "eu-west-2"
}

variable "availability_zones" {
  description = "Availability Zones used for the subnets. The list order maps to the subnet CIDR lists below."
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "project_name" {
  description = "Prefix used to name every resource, so they are easy to find and delete together."
  type        = string
  default     = "project4"
}

# --- Networking -------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets, one per Availability Zone. Host the load balancer and the NAT Gateway."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks of the private application subnets, one per Availability Zone. Host the EC2 instances."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks of the private database subnets, one per Availability Zone. Host the RDS DB subnet group."
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

# --- Compute and scaling ----------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type used by the launch template."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances. Two keeps one instance per Availability Zone."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Number of instances the Auto Scaling group aims to keep running."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances the group is allowed to reach."
  type        = number
  default     = 4
}

variable "health_check_grace_period" {
  description = "Seconds the Auto Scaling group waits before acting on the load balancer health check of a new instance."
  type        = number
  default     = 300
}

# --- Database ---------------------------------------------------------------

variable "db_engine_version" {
  description = "MySQL engine version. Left as a major version so RDS picks the current minor one."
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class. db.t4g.micro is the cheapest burstable Graviton class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB. 20 is the minimum accepted for gp3 on MySQL."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the initial database created inside the instance."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username. The password is never a variable: RDS generates it and stores it in Secrets Manager."
  type        = string
  default     = "admin"
}

variable "db_multi_az" {
  description = "Whether RDS runs a standby in the second Availability Zone. True, as deployed: it roughly doubles the database cost, which is the trade-off being made."
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Days of automated backups kept. Set to 0 to disable them entirely in a throwaway lab."
  type        = number
  default     = 1
}

# --- Observability ----------------------------------------------------------

variable "alert_email" {
  description = "Email address subscribed to the SNS topic. Left empty on purpose: pass it in a .tfvars file or with -var so no address is committed."
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "Average CPU utilisation percentage above which the alarm fires."
  type        = number
  default     = 70
}

variable "log_retention_days" {
  description = "Retention of the Apache log groups in CloudWatch Logs."
  type        = number
  default     = 7
}

# --- Tagging ----------------------------------------------------------------

variable "common_tags" {
  description = "Tags applied to every resource through the provider default_tags block."
  type        = map(string)
  default = {
    Project     = "Project4"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}
