# The database instance.
#
# No password appears in this file, in any variable, or in the state as a
# plaintext value I chose: manage_master_user_password tells RDS to generate
# the master password itself and store it in AWS Secrets Manager, where it also
# owns the rotation. The ARN of that secret is what the iam module grants
# access to.

resource "aws_db_instance" "mysql" {
  identifier = "${var.name_prefix}-mysql"

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # gp3 with no Provisioned IOPS: nothing here has an IO profile that would
  # justify paying for them.
  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  db_name  = var.db_name
  username = var.username

  # RDS creates and manages the secret. There is no `password` argument here on
  # purpose: the two are mutually exclusive.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  # The two settings that keep the database off the Internet. Even with
  # publicly_accessible = true it would have no route out, but both controls
  # are independent and both are set.
  publicly_accessible = false

  # The standby lives in the second database subnet, serves no traffic and
  # cannot be read from: it exists so that a zone failure is a failover behind
  # the same endpoint instead of an outage. It also roughly doubles the cost of
  # the database, which is why it is a variable and not a constant.
  multi_az = var.multi_az

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection
  apply_immediately       = var.apply_immediately

  # Minor versions are patched by RDS itself: that is a large part of why this
  # is a managed service and not MySQL on an EC2 instance.
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.name_prefix}-mysql"
  }
}
