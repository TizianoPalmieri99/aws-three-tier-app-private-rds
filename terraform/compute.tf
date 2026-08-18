# Launch template and Auto Scaling group.
#
# The launch template describes how an instance is built. The Auto Scaling
# group decides how many of them exist and where. Nothing here launches an
# instance directly.

# Look up the current Amazon Linux 2023 AMI at plan time instead of pinning an
# ID that goes stale and is region-specific.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # Excludes the minimal variant, which is named al2023-ami-minimal-*.
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "web" {
  name          = "${var.project_name}-launch-template"
  description   = "Amazon Linux 2023 web server with the CloudWatch Agent, no key pair, managed through Systems Manager"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # No key_name on purpose: there is no SSH key pair anywhere in this project.

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  # Only the security group is set, not a subnet. Choosing the subnet is the
  # Auto Scaling group's job, and that is what spreads instances across zones.
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # The version of the bootstrap script that also installs and configures the
  # CloudWatch Agent, so a replacement instance ships its Apache logs without
  # anybody touching it. aws_launch_template expects base64, which is what
  # filebase64 returns.
  user_data = filebase64("${path.module}/../user-data/install-apache-cloudwatch.sh")

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  # Tags for the instances and volumes the template produces. Neither the tags
  # on the template itself nor the provider default_tags reach them, so the
  # common tags are merged in here explicitly.
  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, {
      Name = "${var.project_name}-web"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.common_tags, {
      Name = "${var.project_name}-web-root"
    })
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

resource "aws_autoscaling_group" "web" {
  # The group built in the Console ended up named project4-launch-template,
  # which is confusing enough that Terraform gives it an accurate name instead.
  # The CloudWatch alarm in monitoring.tf reads this name from the resource, so
  # the dimension follows automatically.
  name = "${var.project_name}-web-asg"

  # Private application subnets only. This is what keeps the instances off the
  # Internet.
  vpc_zone_identifier = aws_subnet.app[*].id

  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size

  # Registers every instance it creates with the target group, and deregisters
  # them on the way out.
  target_group_arns = [aws_lb_target_group.web.arn]

  # ELB health checks, not just the EC2 status checks: an instance whose web
  # server stopped answering is replaced even though the instance itself is
  # still running.
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # The instances are tagged by the launch template above, so nothing needs to
  # be propagated from here.
  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-asg"
    propagate_at_launch = false
  }
}
