# Outbound-only path for the private subnets.
#
# How many gateways get created is the environment's decision, not the module's:
#
#   single_nat_gateway = true   one gateway, shared by every zone. Cheapest, and
#                               losing that zone takes the outbound path of the
#                               other zones with it.
#   single_nat_gateway = false  one gateway per public subnet, so each zone has
#                               its own way out and survives on its own.

locals {
  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)
}

# Static public address each NAT Gateway presents to the Internet.
resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip-${count.index}"
  }
}

# The NAT Gateway sits in a public subnet, because it needs the route to the
# Internet Gateway to do its job.
#
# depends_on is genuinely needed here: this resource never references the
# Internet Gateway, but AWS rejects the NAT Gateway if the Internet Gateway is
# not attached to the VPC yet.
resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name_prefix}-nat-gateway-${count.index}"
  }

  depends_on = [aws_internet_gateway.main]
}
