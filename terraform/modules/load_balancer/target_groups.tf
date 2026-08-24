# The target group is not a server and not a hop in the traffic path. It is the
# list of backend targets plus the health check that decides which of them the
# load balancer is allowed to use.
#
# No targets are registered here: the Auto Scaling group in the compute module
# attaches its instances to this group as it creates them.

resource "aws_lb_target_group" "this" {
  name        = "${var.name_prefix}-web-tg"
  target_type = "instance"
  protocol    = "HTTP"
  port        = 80
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = var.health_check_path
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # Give an instance being replaced a few seconds to finish in-flight requests
  # before it is removed from the group.
  deregistration_delay = var.deregistration_delay

  tags = {
    Name = "${var.name_prefix}-web-tg"
  }
}
