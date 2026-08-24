# The load balancer itself: the only public entry point of the architecture.
# It sits in the public subnets; everything it forwards to sits in private ones.

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  # internal = false is what makes it internet-facing.
  internal = false

  security_groups = [var.security_group_id]

  # One subnet per Availability Zone, so the load balancer keeps a node in each
  # of them.
  subnets = var.public_subnet_ids

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}
