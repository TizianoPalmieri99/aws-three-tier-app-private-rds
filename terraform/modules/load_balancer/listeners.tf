# The listener is what actually accepts connections. Port 80 only: an HTTPS
# listener would need a certificate, and a certificate needs a domain name.

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  protocol          = "HTTP"
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
