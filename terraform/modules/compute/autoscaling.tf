# The Auto Scaling group decides how many instances exist and where they run.
#
# There is no scaling policy in this project. The group holds a fixed desired
# capacity and replaces instances that fail their health check; what watches
# CPU here is the alarm in the monitoring module, which notifies rather than
# scales. Naming that difference is the point: replacing a dead instance and
# adding a new one under load are two different jobs.

resource "aws_autoscaling_group" "web" {
  name = "${var.name_prefix}-web-asg"

  # Private application subnets only. This is what keeps the instances off the
  # Internet.
  vpc_zone_identifier = var.app_subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  # Registers every instance it creates with the target group, and deregisters
  # them on the way out.
  target_group_arns = [var.target_group_arn]

  # ELB health checks, not just the EC2 status checks: an instance whose web
  # server stopped answering is replaced even though the instance itself is
  # still running.
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # The instances are tagged by the launch template, so nothing needs to be
  # propagated from here.
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-web-asg"
    propagate_at_launch = false
  }
}
