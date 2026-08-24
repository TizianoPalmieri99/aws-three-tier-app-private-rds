# **Terraform Implementation**

The same architecture as the rest of this project, written as Infrastructure as Code. The
console build came first; this is the translation of it, so the two can be compared resource by
resource.

Applying an environment creates a complete stack from nothing: network, security groups,
database, IAM role, load balancer, Auto Scaling group and the observability layer. Nothing is
expected to exist beforehand.

Two deliberate differences from what was deployed by hand, both explained in the main
[README](../README.md):

* the Auto Scaling group is named `<prefix>-web-asg` here, instead of the confusing
  `project4-launch-template` the console build ended up with. The CPU alarm reads the name from
  the compute module, so the dimension follows automatically;
* the two log groups are declared explicitly, while on the manual deployment the CloudWatch
  Agent created them itself on first write. The result is the same logs, with a retention that
  is set up front rather than left to default to "never expire".

## Layout

```text
terraform/
├── modules/
│   ├── network/          VPC, three tiers of subnets, gateways, route tables, security groups
│   ├── database/         DB subnet group and the RDS MySQL instance
│   ├── iam/              instance role, policies, instance profile
│   ├── load_balancer/    ALB, target group, listener
│   ├── compute/          AMI lookup, launch template, Auto Scaling group
│   └── monitoring/       log groups, SNS topic, CPU alarm
├── environments/
│   ├── dev/              the environment that was actually applied
│   ├── staging/
│   └── prod/
├── .gitignore
└── README.md
```

A module says *how* a piece of the architecture is built. An environment says *how big*, *in
which region* and *how many*. That split is the point of the layout: prod runs Multi-AZ, one NAT
Gateway per zone and an encrypted, deletion-protected database, and not a line of module code
changes between it and dev.

Each environment is a separate root module with its own state, so applying dev cannot touch
prod. There is no `terraform apply` at the top of this directory — you always apply from inside
an environment.

Every environment holds the same six files:

| file | what it decides |
|---|---|
| `providers.tf` | Terraform and AWS provider versions, region, default tags |
| `backend.tf` | where the state lives |
| `main.tf` | which modules exist and what each one gets from the others |
| `variables.tf` | the inputs the environment accepts |
| `terraform.tfvars` | the values for *this* environment — committed, and holding no secrets |
| `outputs.tf` | what is printed after apply |

Providers are declared only in `providers.tf`. A module that declares its own provider cannot be
reused against a different region or account, so none of these do.

## What Each Module Creates

**network** — a VPC with DNS support and hostnames; **three** pairs of subnets, one of each per
Availability Zone: public for the load balancer and the NAT Gateways, application for the EC2
instances, database for the DB subnet group. An Internet Gateway; one or more Elastic IPs and
NAT Gateways depending on `single_nat_gateway`; a public route table to the Internet Gateway,
one application route table per subnet pointing at a NAT Gateway, and a database route table
with **no** `0.0.0.0/0` route at all. Then the chain of security groups that defines the tiers:
ALB open on 80 from `0.0.0.0/0`, EC2 open on 80 only from the ALB group, RDS open on 3306 only
from the EC2 group. No rule on port 22 anywhere.

**database** — the DB subnet group and the RDS MySQL instance, not publicly accessible, with
`manage_master_user_password` so RDS generates the master password and keeps it in Secrets
Manager. No password is a variable, and none reaches the state as a value I chose.

**iam** — a role EC2 can assume, carrying `AmazonSSMManagedInstanceCore` and
`CloudWatchAgentServerPolicy`, plus an inline policy allowing `secretsmanager:GetSecretValue` on
**one ARN** — the secret the database module created — and the instance profile that delivers
the role.

**load_balancer** — an internet-facing ALB across the public subnets, a target group on HTTP 80
with a health check, and an HTTP listener forwarding to it.

**compute** — the Amazon Linux 2023 AMI resolved at plan time, a launch template using it with
IMDSv2 required and the User Data script that installs Apache and the CloudWatch Agent, and an
Auto Scaling group across the application subnets attached to the target group. There is no
scaling policy: the group replaces instances that fail their health check, and the alarm in
`monitoring` notifies rather than scales.

**monitoring** — the two Apache log groups with an explicit retention, an SNS topic, an optional
email subscription created only if an address is passed in, and a CPU alarm on the Auto Scaling
group publishing to the topic.

## How the Modules Connect

```text
network ── db subnet ids, db sg id ──> database ── secret arn ──> iam ── profile ──┐
   ├────── public subnet ids, alb sg id ──> load_balancer ── target group arn ─────┤
   └────── app subnet ids, app sg id ─────────────────────────────────────────> compute
                                                     compute ── asg name ──> monitoring
```

Only IDs and ARNs cross a module boundary. The database has to exist before `iam` can name its
secret, and the Auto Scaling group has to exist before `monitoring` can point an alarm at it:
Terraform works both out from the references, which is why there is almost no `depends_on` in
the configuration. The one exception is the NAT Gateway, which never references the Internet
Gateway but cannot be created before it is attached.

The User Data script is not duplicated into the module. Each environment passes the path to
`user-data/install-apache-cloudwatch.sh`, so there is one copy of it in the repository.

## The Three Environments

Only **dev** has ever been applied against a real account. Staging and prod are the same code
with different numbers, and I would rather write that here than let three directories imply
three running stacks.

| | dev | staging | prod |
|---|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| NAT Gateways | 1, shared | 1, shared | **1 per AZ** |
| Instance type | `t3.micro` | `t3.small` | `t3.small` |
| ASG min / desired / max | 2 / 2 / 4 | 2 / 2 / 6 | 4 / 4 / 12 |
| RDS class | `db.t4g.micro` | `db.t4g.small` | `db.t4g.medium` |
| Multi-AZ | yes | yes | yes |
| Encrypted at rest | no | yes | yes |
| Backup retention | 1 day | 7 days | 14 days |
| Final snapshot on destroy | skipped | skipped | **kept** |
| Deletion protection | off | off | **on** |
| CPU alarm / log retention | 70% / 7d | 70% / 14d | 60% / 90d |

Two of those rows are not cosmetic. **Encryption at rest can only be set when the instance is
created** — turning it on later means a snapshot and a restore, which is why staging carries it
too rather than discovering the problem in prod. And **deletion protection blocks
`terraform destroy`**, on purpose: a production database should not disappear because someone
ran the right command in the wrong directory.

## Prerequisites

* Terraform 1.5 or later.
* AWS credentials available through the standard chain — `aws configure`, a named profile with
  `AWS_PROFILE`, or environment variables. No credential is written in this configuration.
* Permissions to create VPC, EC2, Elastic Load Balancing, Auto Scaling, RDS, CloudWatch, SNS,
  Secrets Manager and IAM resources.

## Commands

Always from inside an environment directory:

```bash
cd environments/dev

terraform init      # downloads the provider and links the modules
terraform fmt       # canonical style; -recursive from the terraform/ root
terraform validate  # syntax and references, offline
terraform plan      # what would change, against the real account
terraform apply     # creates real resources and starts charges
```

To receive the alarm notifications, pass an address at apply time rather than committing one:

```bash
terraform apply -var="alert_email=you@example.com"
```

The subscription stays pending until the confirmation link in the email is clicked, and an
unconfirmed subscription receives nothing.

The RDS instance is the slow part of the apply — a Multi-AZ MySQL instance takes several minutes
to come up, and the load balancer answers long before the targets are healthy.

## Cleanup

```bash
terraform destroy
```

Removes everything that environment created. Run it in the environment you applied — each one
has its own state and knows nothing about the others. In prod it will refuse until deletion
protection is turned off, which is the intended behaviour.

**These resources cost money while they exist.** The RDS instance is charged per hour and
Multi-AZ roughly doubles it, the NAT Gateway is charged per hour plus data processed and is not
in the free tier, and the load balancer is charged per hour whether or not it receives traffic.
`terraform destroy` also releases the Elastic IPs, which are billed on their own once unattached.

## Notes

* The master password is never in this repository, never a variable and never in a plan output.
  RDS generates it, stores it in Secrets Manager and owns its rotation.
* The inline IAM policy names one secret ARN, read from the database module. It is never `*` and
  never copied by hand.
* The AMI is resolved from a `data` block at plan time, so the configuration is not pinned to an
  AMI ID that expires and is not tied to one region.
* The launch template enforces IMDSv2 (`http_tokens = "required"`).
* Common tags reach every taggable resource through the provider `default_tags` block in the
  environment. Instances and their volumes are the exception — they are created by the Auto
  Scaling group, not by Terraform — so the tags are merged into the launch template
  `tag_specifications` instead.
* State is local, and `backend.tf` carries the S3 block commented out with the reason. The state
  of this project in particular has no business sitting on a laptop for long: it contains the
  full description of the database.
