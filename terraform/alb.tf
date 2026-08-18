# Application Load Balancer, target group and listener.
#
# The load balancer is the only public entry point of the architecture. It sits
# in the public subnets; everything it forwards to sits in private ones.

resource "aws_lb" "web" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  # internal = false is what makes it internet-facing.
  internal = false

  security_groups = [aws_security_group.alb.id]

  # One subnet per Availability Zone, so the load balancer keeps a node in each
  # of them. [*] expands the counted subnet resource into a list of IDs.
  subnets = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# The target group is not a server and not a hop in the traffic path. It is the
# list of backend targets plus the health check that decides which of them the
# load balancer is allowed to use.
#
# No targets are registered here: the Auto Scaling group in compute.tf attaches
# its instances as it creates them.
resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-web-tg"
  target_type = "instance"
  protocol    = "HTTP"
  port        = 80
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # Give an instance being replaced a few seconds to finish in-flight requests
  # before it is removed from the group.
  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-web-tg"
  }
}

# Port 80 only, as deployed. An HTTPS listener would need a certificate, and a
# certificate needs a domain name.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  protocol          = "HTTP"
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
