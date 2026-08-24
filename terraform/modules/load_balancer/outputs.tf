output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "alb_url" {
  description = "URL to open in a browser once the targets are healthy."
  value       = "http://${aws_lb.this.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the target group, useful for checking target health from the CLI."
  value       = aws_lb_target_group.this.arn
}
