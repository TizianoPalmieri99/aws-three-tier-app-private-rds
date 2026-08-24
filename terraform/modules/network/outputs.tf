# What the other modules consume. Everything that leaves this module is an ID,
# so no other module has to know how the network was built.

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, which hold the load balancer and the NAT Gateways."
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

output "alb_security_group_id" {
  description = "ID of the security group attached to the load balancer."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID of the security group attached to the EC2 instances."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID of the security group attached to the RDS instance."
  value       = aws_security_group.db.id
}

output "nat_gateway_public_ips" {
  description = "Public addresses the private instances present when they reach the Internet outbound."
  value       = aws_eip.nat[*].public_ip
}
