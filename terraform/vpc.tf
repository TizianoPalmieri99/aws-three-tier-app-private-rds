# Network layer: VPC, three pairs of subnets, gateways and routing.
#
# The third pair of subnets is the whole point of this project. The database
# subnets exist so that a route table with no 0.0.0.0/0 route can be attached
# to them, which is what isolates the database tier.

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required so instances get internal DNS names and so the RDS endpoint, the
  # SSM agent and the AWS service endpoints resolve inside the VPC.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# --- Subnets ----------------------------------------------------------------

# Public subnets: load balancer nodes and the NAT Gateway.
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "public"
  }
}

# Private application subnets: the EC2 instances. No public address is ever
# assigned here.
resource "aws_subnet" "app" {
  count = length(var.app_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-app-subnet-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "application"
  }
}

# Private database subnets: the DB subnet group. Two of them are required by
# RDS even for a Single-AZ instance.
resource "aws_subnet" "db" {
  count = length(var.db_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-db-subnet-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "database"
  }
}

# --- Gateways ---------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Static public address the NAT Gateway presents to the Internet.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# One NAT Gateway, in the first public subnet. A production build would use one
# per Availability Zone so that losing a zone does not take the outbound path
# of the other one with it; this is a deliberate cost trade-off for a lab.
#
# depends_on is genuinely needed: this resource never references the Internet
# Gateway, but AWS rejects the NAT Gateway if it is not attached yet.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

# --- Routing ----------------------------------------------------------------

# Public: anything not local goes straight to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Application: outbound only, through the NAT Gateway. The instances need this
# to install packages at first boot and to reach Systems Manager, Secrets
# Manager and CloudWatch.
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-app-rt"
  }
}

# Database: no route block at all. The only route in this table is the implicit
# local one for the VPC CIDR, so nothing in these subnets can reach or be
# reached from the Internet, whatever a security group says.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count = length(aws_subnet.app)

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "db" {
  count = length(aws_subnet.db)

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}
