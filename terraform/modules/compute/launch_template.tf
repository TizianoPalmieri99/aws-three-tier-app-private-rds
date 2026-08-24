# The launch template describes how an instance is built. It does not build
# one: that is the Auto Scaling group's job.

resource "aws_launch_template" "web" {
  name          = "${var.name_prefix}-launch-template"
  description   = "Amazon Linux 2023 web server with the CloudWatch Agent, no key pair, managed through Systems Manager"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # No key_name on purpose: there is no SSH key pair anywhere in this project.

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Only the security group is set, not a subnet. Choosing the subnet is the
  # Auto Scaling group's job, and that is what spreads instances across zones.
  vpc_security_group_ids = [var.security_group_id]

  # The bootstrap script lives outside the terraform directory, in user-data/,
  # so the manual build and the Terraform build run the same file. The path is
  # passed in by the environment. aws_launch_template expects base64, which is
  # what filebase64 returns.
  user_data = filebase64(var.user_data_path)

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
      Name = "${var.name_prefix}-web"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.common_tags, {
      Name = "${var.name_prefix}-web-root"
    })
  }

  tags = {
    Name = "${var.name_prefix}-launch-template"
  }
}
