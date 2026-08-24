# What the role is trusted by, and what it is allowed to do.

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
# created for this database, passed in by the environment from the database
# module, so it is never copied by hand and never widened to "*".
data "aws_iam_policy_document" "read_db_secret" {
  statement {
    sid       = "ReadRdsMasterSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "read_db_secret" {
  name   = "${var.name_prefix}-read-db-secret"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}
