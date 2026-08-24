# Values for the prod environment.
#
# This is where the module knobs stop being decoration. Never applied against a
# real account — only dev has been — but it is what the differences would be.

aws_region         = "eu-west-2"
availability_zones = ["eu-west-2a", "eu-west-2b"]

name_prefix = "project4-prd"

vpc_cidr            = "10.2.0.0/16"
public_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]
app_subnet_cidrs    = ["10.2.3.0/24", "10.2.4.0/24"]
db_subnet_cidrs     = ["10.2.5.0/24", "10.2.6.0/24"]

# One NAT Gateway per Availability Zone, each with its own route table. It
# roughly doubles the NAT bill and removes the single point of failure dev and
# staging accept: losing a zone no longer takes the outbound path of the
# surviving zone with it.
single_nat_gateway = false

instance_type = "t3.small"

# A higher floor, so losing one instance is not losing half the fleet.
asg_min_size         = 4
asg_desired_capacity = 4
asg_max_size         = 12

db_engine_version    = "8.0"
db_instance_class    = "db.t4g.medium"
db_allocated_storage = 100
db_name              = "appdb"
db_username          = "admin"

db_multi_az          = true
db_storage_encrypted = true

# Two weeks of automated backups, no snapshot skipped on destroy, and deletion
# protection on. The last one blocks terraform destroy, which is exactly what
# it is there for: a production database should not disappear because someone
# ran the wrong command in the wrong directory.
db_backup_retention_period = 14
db_skip_final_snapshot     = false
db_deletion_protection     = true

# A lower threshold and longer retention: in prod the alarm is meant to arrive
# before the users notice, and the logs are meant to still be there when the
# incident is written up.
cpu_alarm_threshold = 60
log_retention_days  = 90

common_tags = {
  Project     = "Project4"
  Environment = "prod"
  ManagedBy   = "Terraform"
}
