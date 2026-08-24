# No instance is declared anywhere in this module: every instance in this
# architecture is created by the Auto Scaling group from the launch template.
#
# What lives here is the machine image those instances are built from. It is
# looked up at plan time rather than pinned to an AMI ID, because an ID goes
# stale with every AWS release and is different in every region.

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # Excludes the minimal variant, which is named al2023-ami-minimal-*.
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
