# The VPC everything else in this project hangs off.

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required so instances get internal DNS names and so the SSM agent and the
  # load balancer resolve AWS service endpoints.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}
