# The dev environment: six module calls and the wiring between them.
#
# Nothing is declared here directly. What this file decides is which modules
# exist, in what shape, and what each one receives from the others.
#
# The order Terraform builds them in comes out of those references, not out of
# the order they are written: the database has to exist before the iam module
# can name its secret ARN, and the compute module needs the profile that comes
# out of iam.

module "network" {
  source = "../../modules/network"

  name_prefix         = var.name_prefix
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
  single_nat_gateway  = var.single_nat_gateway
}

module "database" {
  source = "../../modules/database"

  name_prefix       = var.name_prefix
  db_subnet_ids     = module.network.db_subnet_ids
  security_group_id = module.network.db_security_group_id

  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  multi_az                = var.db_multi_az
  storage_encrypted       = var.db_storage_encrypted
  backup_retention_period = var.db_backup_retention_period
  skip_final_snapshot     = var.db_skip_final_snapshot
  deletion_protection     = var.db_deletion_protection
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = var.name_prefix

  # The one secret the instances may read. It comes from the database module,
  # so no ARN is ever copied by hand into a policy.
  db_secret_arn = module.database.master_user_secret_arn
}

module "load_balancer" {
  source = "../../modules/load_balancer"

  name_prefix       = var.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  security_group_id = module.network.alb_security_group_id
  health_check_path = "/"
}

module "compute" {
  source = "../../modules/compute"

  name_prefix           = var.name_prefix
  app_subnet_ids        = module.network.app_subnet_ids
  security_group_id     = module.network.app_security_group_id
  instance_profile_name = module.iam.instance_profile_name
  target_group_arn      = module.load_balancer.target_group_arn

  # The bootstrap script lives at the root of the repository, outside the
  # terraform directory, so the manual build and this one run the same file.
  user_data_path = "${path.root}/../../../user-data/install-apache-cloudwatch.sh"

  instance_type    = var.instance_type
  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size
  common_tags      = var.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix            = var.name_prefix
  autoscaling_group_name = module.compute.autoscaling_group_name
  log_retention_days     = var.log_retention_days
  alert_email            = var.alert_email
  cpu_alarm_threshold    = var.cpu_alarm_threshold
}
