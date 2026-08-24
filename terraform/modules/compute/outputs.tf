output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group, which is also the dimension of the CPU alarm."
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "ID of the launch template the group builds instances from."
  value       = aws_launch_template.web.id
}

output "ami_id" {
  description = "AMI the launch template resolved at plan time."
  value       = data.aws_ami.amazon_linux_2023.id
}
