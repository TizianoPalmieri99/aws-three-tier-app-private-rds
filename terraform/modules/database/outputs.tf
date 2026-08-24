# Nothing here is a credential. The secret is exposed as an ARN, which is an
# identifier and not a value: reading it still requires the IAM permission the
# iam module grants.

output "endpoint" {
  description = "Endpoint of the RDS instance. It only resolves to a private address inside the VPC."
  value       = aws_db_instance.mysql.address
}

output "port" {
  description = "Port the instance listens on."
  value       = aws_db_instance.mysql.port
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret RDS manages for the master user."
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.mysql.db_name
}
