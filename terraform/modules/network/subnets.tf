# Three tiers of subnets, one subnet per Availability Zone in each tier.
#
# The third pair is the point of this project. The database subnets exist so
# that a route table with no 0.0.0.0/0 route can be attached to them, which is
# what isolates the database tier.

# Public subnets: load balancer nodes and the NAT Gateways.
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-subnet-${substr(var.availability_zones[count.index], -1, 1)}"
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
    Name = "${var.name_prefix}-app-subnet-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "application"
  }
}

# Private database subnets: the DB subnet group. Two are required by RDS even
# for a Single-AZ instance.
resource "aws_subnet" "db" {
  count = length(var.db_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-db-subnet-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "database"
  }
}
