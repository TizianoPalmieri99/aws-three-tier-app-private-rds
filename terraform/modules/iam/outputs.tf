output "instance_profile_name" {
  description = "Name of the instance profile the launch template attaches to every instance."
  value       = aws_iam_instance_profile.ec2.name
}

output "role_arn" {
  description = "ARN of the instance role."
  value       = aws_iam_role.ec2.arn
}
