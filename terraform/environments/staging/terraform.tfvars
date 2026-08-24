# Values for the staging environment.
#
# Staging exists to be the same shape as prod on a smaller bill: same modules,
# different numbers. It has never been applied against a real account — only
# dev has.

aws_region         = "eu-west-2"
availability_zones = ["eu-west-2a", "eu-west-2b"]

name_prefix = "project4-stg"

vpc_cidr            = "10.1.0.0/16"
public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
app_subnet_cidrs    = ["10.1.3.0/24", "10.1.4.0/24"]
db_subnet_cidrs     = ["10.1.5.0/24", "10.1.6.0/24"]

single_nat_gateway = true

instance_type = "t3.small"

asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 6

db_engine_version    = "8.0"
db_instance_class    = "db.t4g.small"
db_allocated_storage = 20
db_name              = "appdb"
db_username          = "admin"

# Multi-AZ on, so a failover is something that has been rehearsed somewhere
# before it happens in prod for the first time.
db_multi_az = true

# Encrypted, like prod. It cannot be turned on later without a snapshot and a
# restore, so staging is where that is proved to work.
db_storage_encrypted = true

db_backup_retention_period = 7
db_skip_final_snapshot     = true
db_deletion_protection     = false

cpu_alarm_threshold = 70
log_retention_days  = 14

common_tags = {
  Project     = "Project4"
  Environment = "staging"
  ManagedBy   = "Terraform"
}
