# The DB subnet group is how RDS is told which subnets it may place the
# instance in. Two subnets in two Availability Zones are required even for a
# Single-AZ instance: without them RDS has nowhere to fail over to later.

resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "Private database subnets, one per Availability Zone"
  subnet_ids  = var.db_subnet_ids

  tags = {
    Name = "${var.name_prefix}-db-subnet-group"
  }
}
