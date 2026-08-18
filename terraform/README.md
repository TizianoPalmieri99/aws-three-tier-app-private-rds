# **Terraform Implementation**

The same architecture as the rest of this project, written as Infrastructure as Code. The
console build came first; this is the translation of it, so the two can be compared resource by
resource.

Applying this creates a complete stack from nothing: network, security groups, database, IAM
role, load balancer, Auto Scaling group and the observability layer. Nothing is expected to
exist beforehand.

Two deliberate differences from what was deployed by hand, both explained in the main
[README](../README.md):

* the Auto Scaling group is named `project4-web-asg` here, instead of the confusing
  `project4-launch-template` the console build ended up with. The CPU alarm reads the name from
  the resource, so the dimension follows automatically;
* the two log groups are declared explicitly, while on the manual deployment the CloudWatch
  Agent created them itself on first write. The result is the same logs, with a retention that
  is set up front rather than left to default to "never expire".

## What Terraform Creates

Networking:

* a VPC with DNS support and DNS hostnames enabled;
* two public subnets, one per Availability Zone, for the load balancer and the NAT Gateway;
* two private application subnets, one per Availability Zone, for the EC2 instances;
* two private database subnets, one per Availability Zone, for the DB subnet group;
* an Internet Gateway attached to the VPC;
* an Elastic IP and a public NAT Gateway in public subnet A;
* three route tables — public to the Internet Gateway, application to the NAT Gateway, database
  with **no** `0.0.0.0/0` route — and their subnet associations.

Security:

* an ALB security group allowing inbound HTTP from `0.0.0.0/0`;
* an EC2 security group allowing inbound HTTP **only from the ALB security group**;
* an RDS security group allowing MySQL 3306 **only from the EC2 security group**;
* no rule on port 22 anywhere;
* outbound rules left permissive, to match what was deployed rather than to describe something
  better than the truth.

Database:

* a DB subnet group over the two private database subnets;
* a `db.t4g.micro` MySQL instance on gp3 storage, not publicly accessible, **Multi-AZ**, with
  the master password generated and stored in Secrets Manager by RDS itself.

Access:

* an IAM role EC2 can assume, with `AmazonSSMManagedInstanceCore` and
  `CloudWatchAgentServerPolicy`;
* an inline policy allowing `secretsmanager:GetSecretValue` on the ARN of that one database
  secret;
* the instance profile that delivers the role to the instances.

Application layer:

* an internet-facing Application Load Balancer across both public subnets;
* a target group on HTTP port 80 with a health check on `/`;
* an HTTP listener on port 80 forwarding to it;
* a launch template using the current Amazon Linux 2023 AMI, `t3.micro`, no key pair, and the
  User Data that installs Apache **and** the CloudWatch Agent;
* an Auto Scaling group across both private application subnets, min 2, desired 2, max 4,
  attached to the target group.

Observability:

* two CloudWatch log groups, `/project4/apache/access` and `/project4/apache/error`, with a
  retention of 7 days;
* an SNS topic, plus an email subscription if `alert_email` is set;
* a CloudWatch alarm on average `CPUUtilization` of the Auto Scaling group above 70%, publishing
  to the topic.

## File Structure

```text
terraform/
├── provider.tf                 Terraform and AWS provider versions, region, default tags
├── variables.tf                every input value, with defaults matching this architecture
├── vpc.tf                      VPC, six subnets, gateways, three route tables
├── security.tf                 the three security groups and their rules
├── rds.tf                      DB subnet group and the RDS MySQL instance
├── iam.tf                      IAM role, managed policies, the inline secret policy, profile
├── alb.tf                      load balancer, target group and listener
├── compute.tf                  AMI lookup, launch template, Auto Scaling group
├── monitoring.tf               log groups, SNS topic and subscription, CPU alarm
├── outputs.tf                  values printed after apply, including the load balancer URL
├── terraform.tfvars.example    how to override the defaults
└── README.md
```

Terraform loads every `.tf` file in the directory as one configuration, so the split is purely
for readability. The order files are read in does not matter: resources are linked by
reference, and Terraform builds the dependency graph from those references.

The User Data script is not duplicated here. `compute.tf` reads
`../user-data/install-apache-cloudwatch.sh`, so there is one copy of it in the repository.

## How the Files Connect

Everything hangs off `aws_vpc.main`, and one chain is worth following on its own:

```text
rds.tf   aws_db_instance.mysql
            └─ master_user_secret[0].secret_arn
iam.tf        └─ aws_iam_role_policy.read_db_secret   (the ARN, never "*")
                    └─ aws_iam_role.ec2
                         └─ aws_iam_instance_profile.ec2
compute.tf                    └─ aws_launch_template.web
                                   └─ aws_autoscaling_group.web
```

That is why the database is created before the instances: the policy that lets them read the
secret cannot be written until the secret exists. Nothing had to be ordered by hand — the
reference to the ARN is what tells Terraform the order.

The rest follows the same idea. The EC2 ingress rule references `aws_security_group.alb.id`, the
RDS ingress rule references `aws_security_group.ec2.id`, and the alarm dimension references
`aws_autoscaling_group.web.name`. Because those references exist, there is almost no
`depends_on` in the configuration. The one exception is the NAT Gateway, which has no reference
to the Internet Gateway but cannot be created before it is attached to the VPC.

## Prerequisites

* Terraform 1.5 or later.
* AWS credentials available through the standard chain: `aws configure`, a named profile with
  `AWS_PROFILE`, or environment variables. No credential is written in this configuration.
* Permissions to create VPC, EC2, Elastic Load Balancing, Auto Scaling, RDS, Secrets Manager,
  CloudWatch, SNS and IAM resources. Creating the IAM role in particular requires IAM write
  access.

To use a named profile:

```bash
export AWS_PROFILE=my-profile      # PowerShell: $env:AWS_PROFILE = "my-profile"
```

## Commands

```bash
terraform init
```

Downloads the AWS provider and prepares the working directory. Run it once, and again after
changing provider versions.

```bash
terraform fmt
```

Rewrites the files in the canonical style. `terraform fmt -check` reports differences without
changing anything, which is what a CI pipeline would run.

```bash
terraform validate
```

Checks that the configuration is internally consistent: syntax, argument names, references
between resources. It does not talk to AWS. This is the last check that can be run without
credentials, and it is where this configuration currently stands.

```bash
terraform plan
```

Talks to AWS, compares the configuration with what already exists, and prints what it would
create, change or destroy. Nothing is applied. This is the step to read carefully.

```bash
terraform apply
```

Executes the plan after asking for confirmation. It creates real AWS resources and starts
charges. When it finishes it prints the outputs, including `alb_url`.

To subscribe an address to the alarm topic without putting it in a file:

```bash
terraform apply -var="alert_email=you@example.com"
```

The subscription arrives as a confirmation email and receives nothing until the link in it is
clicked.

Expect the apply to take a while: the RDS instance alone is usually several minutes, and the
load balancer answers before the instances are healthy, because each one runs `dnf update`
before installing Apache.

## Cleanup

```bash
terraform destroy
```

Removes everything this configuration created.

**These resources cost money while they exist.** The NAT Gateway is charged per hour plus data
processed, the load balancer is charged per hour whether or not it receives traffic, the RDS
instance is charged per hour (twice over, because Multi-AZ runs a standby) and its storage and
backups are charged even while it is stopped,
and the instances and their EBS volumes run continuously. `terraform destroy` also releases the
Elastic IP, which is billed on its own once it is no longer attached.

Two things survive a destroy and are worth checking afterwards:

* the Secrets Manager secret is **scheduled** for deletion with a recovery window, not deleted
  immediately, so it stays listed for a few days;
* `skip_final_snapshot = true` means no final snapshot is kept. That is right for a lab and
  wrong for anything else.

Destroying is the right way to clean up: deleting resources by hand in the console leaves the
state file describing things that no longer exist.

## Architecture Flow

Inbound:

```text
Internet
   |
Internet Gateway
   |
Application Load Balancer   (public subnets, ALB security group)
   |
Target Group                (HTTP :80, health check on /)
   |
Auto Scaling Group
   |
EC2 private instances       (private app subnets, no public IP)
   |
RDS MySQL                   (private DB subnets, 3306 from the EC2 security group)
```

Outbound, from an instance:

```text
EC2
-> Application Route Table  (0.0.0.0/0 -> NAT Gateway)
-> NAT Gateway              (public subnet, Elastic IP)
-> Internet Gateway
-> Internet / AWS endpoints (Systems Manager, Secrets Manager, CloudWatch)
```

The database has no equivalent path. Its route table has only the local VPC route.

## Notes

* The AMI is resolved at plan time from a `data` block, so the configuration is not pinned to an
  AMI ID that expires and is not tied to one region.
* `manage_master_user_password = true` is what keeps the password out of this repository and out
  of the state as a value anyone chose. There is no `password` argument, and the two are
  mutually exclusive.
* `rds_secret_arn` is an output because it is an identifier, not a value. Reading the secret
  still requires the IAM permission.
* The launch template enforces IMDSv2 (`http_tokens = "required"`).
* The Auto Scaling group uses `health_check_type = "ELB"`, so an instance whose web server has
  stopped answering is replaced even though the instance itself is still running.
* The log groups are declared explicitly rather than left to the CloudWatch Agent, which would
  create them with retention set to "never expire" and leave them behind after a destroy.
* Common tags are applied to every taggable resource through the provider `default_tags` block.
  Instances and their volumes are the exception: they are created by the Auto Scaling group, not
  by Terraform, so the tags are merged into the launch template `tag_specifications` instead.
* State is local. A shared backend such as S3 with state locking is what this would need before
  more than one person applied it.
