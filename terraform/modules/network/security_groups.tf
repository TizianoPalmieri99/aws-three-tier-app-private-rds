# Security groups: the chain that defines the three tiers.
#
#   Internet -> ALB SG -> EC2 SG -> RDS SG
#
# Each group names the previous one as its source instead of a CIDR block, so
# no IP address is written down anywhere and the rules keep working when Auto
# Scaling replaces an instance.
#
# Rules are declared as standalone aws_vpc_security_group_*_rule resources
# rather than inline blocks, so a change to one rule does not rewrite the whole
# group.

# --- Load balancer ----------------------------------------------------------

# The only security group exposed to the Internet.
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allows inbound HTTP from the Internet to the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

# Permissive on purpose: this mirrors what was deployed in the console, where
# outbound rules were left at the AWS default while building and testing.
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "All outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# --- Application tier -------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Allows inbound HTTP only from the load balancer security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-ec2-sg"
  }
}

# There is deliberately no rule for port 22. Administration goes through
# Systems Manager Session Manager, see the iam module.
resource "aws_vpc_security_group_ingress_rule" "app_http_from_alb" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP from the load balancer only"

  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# Outbound is needed for the first-boot package install, the SSM agent, the
# Secrets Manager call and the CloudWatch Agent. Left permissive, as deployed.
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# --- Database tier ----------------------------------------------------------

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Allows inbound MySQL only from the application security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-rds-sg"
  }
}

# The rule that makes the database tier a tier. Source is the EC2 security
# group: not my laptop, not a CIDR block, not the VPC range.
resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_app" {
  security_group_id = aws_security_group.db.id
  description       = "MySQL from the application tier only"

  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

# Kept as deployed. It changes nothing on its own: the database subnets have no
# route to the Internet, so there is nowhere for this traffic to go.
resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  description       = "All outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
