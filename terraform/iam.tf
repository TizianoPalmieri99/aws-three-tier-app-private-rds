# IAM role for the application instances.
#
# It does three jobs: Session Manager access, CloudWatch Agent permissions, and
# read access to exactly one secret. No IAM user and no access key exists
# anywhere in this project — the instances receive temporary credentials from
# the instance metadata service.

# Trust policy: only the EC2 service may assume this role.
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-ec2-role"
  description        = "Application instances: Systems Manager, CloudWatch Agent, and read of the RDS secret"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# What Session Manager needs. The ARN belongs to AWS itself, so there is no
# account ID in it.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# What the CloudWatch Agent needs to create log streams and publish log events.
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# The least-privilege part. The resource is the ARN of the one secret RDS
# created for this database, read from the instance itself, so it is never
# copied by hand and never widened to "*".
data "aws_iam_policy_document" "read_db_secret" {
  statement {
    sid       = "ReadRdsMasterSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.mysql.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "read_db_secret" {
  name   = "${var.project_name}-read-db-secret"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

# An instance profile is the wrapper EC2 needs in order to receive a role. The
# launch template references this, not the role directly.
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "${var.project_name}-ec2-profile"
  }
}
