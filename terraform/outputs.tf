# Values printed after apply.
#
# Nothing here prints a credential. The database secret is exposed as an ARN,
# which is an identifier and not a value: reading it still requires the IAM
# permission granted in iam.tf.

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.web.dns_name
}

output "alb_url" {
  description = "URL to open in a browser once the targets are healthy."
  value       = "http://${aws_lb.web.dns_name}"
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, which hold the load balancer and the NAT Gateway."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "IDs of the private application subnets, which hold the EC2 instances."
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "IDs of the private database subnets, which have no route to the Internet."
  value       = aws_subnet.db[*].id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group, which is also the dimension of the CPU alarm."
  value       = aws_autoscaling_group.web.name
}

output "target_group_arn" {
  description = "ARN of the target group, useful for checking target health from the CLI."
  value       = aws_lb_target_group.web.arn
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance. It only resolves to a private address inside the VPC."
  value       = aws_db_instance.mysql.address
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret RDS manages for the master user. The instance role can read this one and no other."
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic the CPU alarm publishes to."
  value       = aws_sns_topic.alerts.arn
}

output "apache_log_groups" {
  description = "CloudWatch log groups the CloudWatch Agent writes the Apache logs to."
  value = [
    aws_cloudwatch_log_group.apache_access.name,
    aws_cloudwatch_log_group.apache_error.name,
  ]
}

output "nat_gateway_public_ip" {
  description = "Public address the private instances present when they reach the Internet outbound."
  value       = aws_eip.nat.public_ip
}
