# Routing. Three route tables, and the difference between them is the whole
# three-tier design: the subnets themselves are identical until one is
# associated with them.

# Public: anything not local goes straight to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Application: outbound only, through a NAT Gateway. The instances need this to
# install packages at first boot and to reach Systems Manager, Secrets Manager
# and CloudWatch.
#
# One table per application subnet, so switching an environment to one NAT
# Gateway per zone changes which gateway each table points at and nothing else.
resource "aws_route_table" "app" {
  count = length(aws_subnet.app)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.name_prefix}-app-rt-${substr(var.availability_zones[count.index], -1, 1)}"
  }
}

resource "aws_route_table_association" "app" {
  count = length(aws_subnet.app)

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# Database: no route block at all. The only route in this table is the implicit
# local one for the VPC CIDR, so nothing in these subnets can reach or be
# reached from the Internet, whatever a security group says.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-db-rt"
  }
}

resource "aws_route_table_association" "db" {
  count = length(aws_subnet.db)

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}
