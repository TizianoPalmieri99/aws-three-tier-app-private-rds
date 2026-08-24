# Values printed after apply.
#
# Nothing here prints a credential. The database secret is exposed as an ARN,
# which is an identifier and not a value: reading it still requires the IAM
# permission granted in the iam module.

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = module.load_balancer.alb_dns_name
}

output "alb_url" {
  description = "URL to open in a browser once the targets are healthy."
  value       = module.load_balancer.alb_url
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, which hold the load balancer and the NAT Gateways."
  value       = module.network.public_subnet_ids
}

output "app_subnet_ids" {
  description = "IDs of the private application subnets, which hold the EC2 instances."
  value       = module.network.app_subnet_ids
}

output "db_subnet_ids" {
  description = "IDs of the private database subnets, which have no route to the Internet."
  value       = module.network.db_subnet_ids
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group, which is also the dimension of the CPU alarm."
  value       = module.compute.autoscaling_group_name
}

output "target_group_arn" {
  description = "ARN of the target group, useful for checking target health from the CLI."
  value       = module.load_balancer.target_group_arn
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance. It only resolves to a private address inside the VPC."
  value       = module.database.endpoint
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret RDS manages for the master user. The instance role can read this one and no other."
  value       = module.database.master_user_secret_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic the CPU alarm publishes to."
  value       = module.monitoring.sns_topic_arn
}

output "apache_log_groups" {
  description = "CloudWatch log groups the CloudWatch Agent writes the Apache logs to."
  value       = module.monitoring.log_group_names
}

output "nat_gateway_public_ips" {
  description = "Public addresses the private instances present when they reach the Internet outbound."
  value       = module.network.nat_gateway_public_ips
}
