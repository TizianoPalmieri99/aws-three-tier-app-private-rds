# The role the application instances run as, and the instance profile that
# delivers it.
#
# It does three jobs: Session Manager access, CloudWatch Agent permissions, and
# read access to exactly one secret. No IAM user and no access key exists
# anywhere in this project — the instances receive temporary credentials from
# the instance metadata service.

resource "aws_iam_role" "ec2" {
  name               = "${var.name_prefix}-ec2-role"
  description        = "Application instances: Systems Manager, CloudWatch Agent, and read of the RDS secret"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.name_prefix}-ec2-role"
  }
}

# An instance profile is the wrapper EC2 needs in order to receive a role. The
# launch template references this, not the role directly.
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "${var.name_prefix}-ec2-profile"
  }
}
