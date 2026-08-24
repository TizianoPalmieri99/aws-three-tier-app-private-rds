variable "name_prefix" {
  description = "Prefix used to name the role and the instance profile."
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret the instances are allowed to read. One ARN, never a wildcard."
  type        = string
}
