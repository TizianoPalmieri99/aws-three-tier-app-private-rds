variable "name_prefix" {
  description = "Prefix used to name the instance and the subnet group."
  type        = string
}

variable "db_subnet_ids" {
  description = "Private database subnets the DB subnet group is built from."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the instance. It should allow 3306 only from the application tier."
  type        = string
}

variable "engine_version" {
  description = "MySQL engine version. Left as a major version so RDS picks the current minor one."
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GiB. 20 is the minimum accepted for gp3 on MySQL."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Ceiling for storage autoscaling in GiB. 0 disables it, so a lab cannot grow its own bill."
  type        = number
  default     = 0
}

variable "db_name" {
  description = "Name of the initial database created inside the instance."
  type        = string
}

variable "username" {
  description = "Master username. The password is never a variable: RDS generates it and stores it in Secrets Manager."
  type        = string
  default     = "admin"
}

variable "multi_az" {
  description = "Whether RDS runs a standby in the second Availability Zone. It roughly doubles the database cost."
  type        = bool
}

variable "storage_encrypted" {
  description = "Encryption at rest. It can only be set at creation time: turning it on later means a snapshot and a restore."
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "Customer managed KMS key for encryption at rest. Null uses the AWS managed key for RDS."
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Days of automated backups kept. 0 disables them entirely."
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Whether destroy skips the final snapshot. True in a lab, because a snapshot keeps costing after everything else is gone."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Blocks deletion of the instance until it is turned off. It also blocks terraform destroy, which is the point."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Whether changes are applied at once instead of in the next maintenance window. True is fine in a lab and disruptive in production."
  type        = bool
  default     = true
}
