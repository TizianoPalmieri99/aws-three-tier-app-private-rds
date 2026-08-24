# The only door into the VPC from the Internet. Attaching it is what makes the
# public subnets public, once a route table points at it.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}
