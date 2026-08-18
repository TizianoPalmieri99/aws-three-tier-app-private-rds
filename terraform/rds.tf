# The database tier: DB subnet group and the RDS MySQL instance.
#
# No password appears in this file, in any variable, or in the state as a
# plaintext value I chose: manage_master_user_password tells RDS to generate
# the master password itself and store it in AWS Secrets Manager, where it also
# owns the rotation. The ARN of that secret is what iam.tf grants access to.

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Private database subnets, one per Availability Zone"
  subnet_ids  = aws_subnet.db[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # gp3 with no Provisioned IOPS: this lab has no IO profile that would justify
  # paying for them.
  storage_type          = "gp3"
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 0 # storage autoscaling off, so a lab cannot grow its own bill

  db_name  = var.db_name
  username = var.db_username

  # RDS creates and manages the secret. There is no `password` argument here on
  # purpose: the two are mutually exclusive.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # The two settings that keep the database off the Internet. Even with
  # publicly_accessible = true it would have no route out, but both controls
  # are independent and both are set.
  publicly_accessible = false

  # False to match the lab. The subnet group above already spans two zones, so
  # flipping this to true is the only change needed for high availability.
  multi_az = var.db_multi_az

  # Matches what was deployed. Production would be true, with a customer
  # managed KMS key.
  storage_encrypted = false

  backup_retention_period = var.db_backup_retention_period
  skip_final_snapshot     = true # a lab snapshot would keep costing after destroy
  deletion_protection     = false
  apply_immediately       = true

  # Minor versions are patched by RDS itself: that is a large part of why this
  # is a managed service and not MySQL on an EC2 instance.
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
