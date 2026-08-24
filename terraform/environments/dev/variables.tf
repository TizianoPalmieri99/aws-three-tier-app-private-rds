# Inputs of this environment. The values are in terraform.tfvars, so this file
# stays the same across dev, staging and prod and only the values move.

variable "aws_region" {
  description = "AWS region the whole stack is deployed into."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones used for the subnets. The list order maps to the subnet CIDR lists below."
  type        = list(string)
}

variable "name_prefix" {
  description = "Prefix used to name every resource, so an environment is easy to find and delete as a whole."
  type        = string
}

# --- Networking -------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets, one per Availability Zone. Host the load balancer and the NAT Gateways."
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks of the private application subnets, one per Availability Zone. Host the EC2 instances."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks of the private database subnets, one per Availability Zone. Host the DB subnet group."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "True for one shared NAT Gateway, false for one per Availability Zone."
  type        = bool
}

# --- Compute ----------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type used by the launch template."
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of instances. Two keeps one instance per Availability Zone."
  type        = number
}

variable "asg_desired_capacity" {
  description = "Number of instances the Auto Scaling group aims to keep running."
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of instances the group is allowed to reach."
  type        = number
}

# --- Database ---------------------------------------------------------------

variable "db_engine_version" {
  description = "MySQL engine version. Left as a major version so RDS picks the current minor one."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB. 20 is the minimum accepted for gp3 on MySQL."
  type        = number
}

variable "db_name" {
  description = "Name of the initial database created inside the instance."
  type        = string
}

variable "db_username" {
  description = "Master username. The password is never a variable: RDS generates it and stores it in Secrets Manager."
  type        = string
}

variable "db_multi_az" {
  description = "Whether RDS runs a standby in the second Availability Zone."
  type        = bool
}

variable "db_storage_encrypted" {
  description = "Encryption at rest. It can only be set at creation time."
  type        = bool
}

variable "db_backup_retention_period" {
  description = "Days of automated backups kept."
  type        = number
}

variable "db_skip_final_snapshot" {
  description = "Whether destroy skips the final snapshot."
  type        = bool
}

variable "db_deletion_protection" {
  description = "Blocks deletion of the instance, terraform destroy included."
  type        = bool
}

# --- Observability ----------------------------------------------------------

variable "alert_email" {
  description = "Address subscribed to the SNS topic. Left empty so no address is committed; pass it with -var or in a local override."
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "Average CPU utilisation percentage above which the alarm fires."
  type        = number
}

variable "log_retention_days" {
  description = "Retention of the Apache log groups in CloudWatch Logs."
  type        = number
}

# --- Tagging ----------------------------------------------------------------

variable "common_tags" {
  description = "Tags applied to every resource through the provider default_tags block."
  type        = map(string)
}
