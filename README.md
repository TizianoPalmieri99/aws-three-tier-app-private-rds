# **Three-Tier Application with Private RDS**

## Goal

Project 3 already had a highly available web tier: a load balancer in public subnets, two EC2
instances in private ones, an Auto Scaling group keeping them alive. But the app stored nothing.
There was no data to protect.

Here I added a database, and that changes the whole security design. Three tiers now: the load
balancer as the public entry point, the instances in the middle, RDS MySQL at the bottom. Each
tier talks only to the one next to it.

The database sits in its own pair of subnets with no route to the Internet, accepts connections
only from the application security group, and its master password is written down nowhere. It
lives in Secrets Manager and the instances read it through an IAM role.

Built by hand in the console in `eu-west-2` first, then written as Terraform in
[`terraform/`](terraform/).

## Architecture

![AWS architecture](architecture-diagram.png)

```text
Internet → Internet Gateway → Application Load Balancer (public subnets)
        → target group → Auto Scaling group → EC2 A / EC2 B (private app subnets)
        → TCP 3306 → RDS MySQL, Multi-AZ (private DB subnets)
```

Two things in the diagram are not what I deployed:

* **Route 53** is marked optional. I have no domain. The app is reached on the load balancer DNS
  name.
* The legend shows **443** on the ALB security group and **restrictive outbound rules**. Neither
  is true. My listener is HTTP on 80 and I left outbound at the AWS default while building.

Everything else is running, including the Multi-AZ database with its standby in the second zone.

## Repository Layout

```text
.
├── README.md
├── architecture-diagram.png
├── user-data/
│   ├── install-apache.sh                the first bootstrap script
│   ├── install-apache-cloudwatch.sh     the current one: same plus the CloudWatch Agent
│   └── amazon-cloudwatch-agent.json     the agent config on its own
└── terraform/                           the same architecture as code
    └── README.md
```

## What I Built

| | |
|---|---|
| VPC | two AZs, **three pairs of subnets**: public, private app, private DB |
| Route tables | public to the Internet Gateway, app to the NAT Gateway, DB with **no `0.0.0.0/0` route at all** |
| Security groups | ALB from `0.0.0.0/0` on 80, EC2 on 80 from the ALB SG, RDS on 3306 from the EC2 SG |
| ALB | internet-facing, both public subnets, HTTP 80 to target group `project4-web-tg` |
| Launch template | Amazon Linux, EC2 SG, instance profile, User Data, no key pair, no subnet |
| Auto Scaling | across the two private app subnets, min 2, desired 2, max 4 |
| RDS | MySQL, `db.t4g.micro`, gp3, **Multi-AZ**, `Publicly accessible = No` |
| Credentials | managed by RDS in Secrets Manager |
| IAM | `project4-ec2-role`: SSM core, CloudWatch Agent, and one inline policy on a single secret ARN |
| Monitoring | CloudWatch CPU alarm at 70% into an SNS topic with an email subscription |
| Logs | Apache access and error to CloudWatch Logs through the agent |
| Access | Session Manager. Port 22 closed everywhere, no key pair |

Six subnets instead of four, because of that third route table. The instances need to get out:
packages at first boot, the SSM agent reaching Systems Manager, calls to Secrets Manager and
CloudWatch. So their table points `0.0.0.0/0` at the NAT Gateway.

The database needs none of that. Its route table has the local VPC route and nothing else. RDS
cannot start a connection out and nothing outside can reach it, whatever a security group says.

## The Security Chain

```text
Internet
   |  HTTP 80 from 0.0.0.0/0
   v
ALB security group
   |  HTTP 80 from the ALB security group
   v
EC2 security group
   |  MySQL 3306 from the EC2 security group
   v
RDS security group
```

The ALB security group is the only one that mentions `0.0.0.0/0`. It is the perimeter. Nothing
below it names an IP range: each group references the one above it. That is what makes the rules
survive Auto Scaling replacing an instance with a new private IP.

There is no path from the Internet to those subnets anyway, but the two controls are independent
and I want both.

**On outbound rules, honestly:** I left them permissive, which is the AWS default. A hardened
version limits the instances to 3306 towards RDS plus 443 for the AWS endpoints. I have not done
it, so I am not claiming it.

## The Database Tier

| Setting | Value | Why |
|---|---|---|
| Engine | MySQL Community | the default relational engine at SAA level |
| Class | `db.t4g.micro` | smallest burstable Graviton class |
| Storage | gp3 | no Provisioned IOPS, this lab has no IO profile |
| Deployment | **Multi-AZ** | a standby in the second zone, so a zone failure is a failover |
| Public access | No | the endpoint only resolves inside the VPC |
| Subnet group | the two private DB subnets | required by RDS, and where the standby lives |

The question I care about is not how to create a database. It is what RDS gives me that MySQL on
an EC2 instance would not: backups, patching, failover, storage and metrics stop being my
problem. What I lose is root on the host. No shell, only parameters and an endpoint.

Multi-AZ is availability, not performance. The standby serves no traffic and I cannot read from
it. It takes the writes synchronously and sits there so a failure promotes it, with the endpoint
following. The app never finds out, because all it knows is the endpoint. Read replicas are the
other tool, asynchronous and readable, and they solve a different problem.

## Secrets Manager and IAM

The master password is not in the code, not in User Data, not in this repository and not in a
config file. RDS created the secret and manages it, and the instances read it at runtime through
`project4-ec2-role`, attached to the launch template as an instance profile.

The part that matters is the inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:eu-west-2:<ACCOUNT_ID>:secret:<RDS_SECRET_NAME>-<SUFFIX>"
    }
  ]
}
```

One ARN, not `*`. If the account ends up with twenty secrets these instances still read exactly
one. There is no IAM user, no access key and no password on the instances. The credentials they
use are temporary and rotated by AWS.

I tested it instead of assuming it. From a **Session Manager** shell (no SSH, no key pair, no
inbound rule) I read the secret with the instance role, connected to the RDS endpoint with the
MySQL client and ran queries. That one test covers the instance profile, the inline policy, the
outbound path to the AWS endpoints, the private DNS resolution of the endpoint and the 3306
rule.

## Observability

Running: standard EC2 metrics, a CloudWatch alarm on `CPUUtilization` above 70% for the Auto
Scaling group, and an SNS topic `project4-alerts` with an email subscription behind it. Apache
access and error logs go to CloudWatch Logs through the agent, into `/project4/apache/access`
and `/project4/apache/error`, one stream per instance ID.

The agent is configured **in the launch template**, not on the instances. Installing it by hand
over Session Manager works right up until the next instance replacement, then quietly stops
working on the new one. That is also why adding it meant a new template version and an instance
refresh with minimum healthy percentage 50, so one instance kept serving while the other was
replaced.

Centralising the logs matters more here than anywhere else. The Auto Scaling group can terminate
an instance at any moment and `/var/log/httpd/` goes with it.

Having a metric is not the same as monitoring it. I built **no** alarms on ALB 5xx or
`TargetResponseTime`, on `UnHealthyHostCount` (which is the one I would actually want first), or
on RDS `FreeStorageSpace` and `DatabaseConnections`. Memory and disk on EC2 are not in the
standard set at all: the hypervisor cannot see inside the instance, which is what the agent is
for.

One naming detail I am documenting instead of hiding. My Auto Scaling group is called
**`project4-launch-template`**, because that is the name the console suggested when I created it
from the template. It is the Auto Scaling group. The alarm uses that name too.

## Traffic Flow

```text
Client → Internet Gateway → ALB (public subnets, ALB SG)
       → target group → EC2 (private app subnet, 80 from the ALB SG)
       → RDS endpoint (private DB subnet, 3306 from the EC2 SG)
```

Outbound from an instance goes through the private app route table to the NAT Gateway, out the
Internet Gateway, to Systems Manager, Secrets Manager and CloudWatch. Outbound from the database
goes nowhere: its route table has the local route only.

## Validation

What I checked: the Auto Scaling group created both instances itself, in the two private app
subnets, neither with a public IP; both registered in `project4-web-tg` and reported **Healthy**;
RDS is private, not publicly accessible, and running Multi-AZ with the standby in the second
zone; the RDS security group allows 3306 only from the EC2 security group; Secrets Manager holds
the RDS-managed credentials and the instances carry the role; **the database answers queries**,
from a Session Manager shell, using the role to read the secret, so the whole chain works rather
than just existing; Session Manager itself works with no key pair and no rule on 22; CloudWatch
gets CPU for the group, the alarm is wired to the SNS topic, and both log groups receive Apache
logs with one stream per instance ID.

What I have not done:

* **the web page does not talk to the database.** The instances serve a static test page. I made
  the connection by hand from a shell, not from application code. That is the piece still
  missing.
* I have not fired the CPU alarm on purpose, so I have never seen the email arrive.
* I have not tested failure behaviour: terminating an instance to watch the group replace it,
  stopping Apache to see a target go unhealthy, or rebooting RDS with failover to see how long
  the endpoint takes to follow the standby.

So the infrastructure is built, isolated the way I wanted, and proven tier by tier up to a real
MySQL session from the application tier. What is missing is application code doing the same
thing on every request.

## Cleanup

Nothing here is covered by a free allowance. The NAT Gateway costs per hour plus data, the load
balancer per hour whether it gets traffic or not, and RDS twice over because Multi-AZ runs a
standby. Storage and backups are charged even when the instance is stopped, and a stopped RDS
instance restarts itself after seven days. I delete everything the same day.

1. The **Auto Scaling group first**, or it replaces the instances I terminate.
2. The load balancer, then the target group.
3. The RDS instance, skipping the final snapshot for a lab, then the DB subnet group.
4. The NAT Gateway, then release its Elastic IP. Unattached, it is billed on its own.
5. Launch template, security groups, route tables, subnets, Internet Gateway, VPC last.
6. The CloudWatch alarm, the two log groups, the SNS topic and its subscription.
7. The secret. It goes into a scheduled deletion with a recovery window rather than
   disappearing, which is worth knowing before wondering why it is still listed.
8. Check no instance, orphan EBS volume or snapshot is left behind.

## What I Learned

* Three tiers is not three groups of servers, it is three blast radiuses. What makes the
  database a tier is that its route table has no way out and its security group names one
  source.
* A DB subnet group has to span two AZs before you can ask for a standby, because that is where
  AWS puts it.
* Multi-AZ is availability, not performance. The standby answers nothing.
* The app never learns that a failover happened. It knows an endpoint, and the endpoint is what
  moves.
* Chaining security groups by reference instead of by CIDR is what makes a rule survive an
  instance being replaced.
* A secret is only as private as the policy that reads it. `GetSecretValue` on `*` throws most
  of the benefit away.
* An instance profile is how an instance receives a role, and the credentials are temporary.
  There is nothing on disk to steal.
* Instance logs are as disposable as the instance.
* Configuring an agent by hand works exactly until the next replacement. The reproducible place
  is the launch template.
* Standard EC2 metrics stop at the hypervisor. CPU is free, memory and disk need an agent inside.

## What I Need to Be Able to Explain

1. What the third pair of subnets buys me, and why four would not have been enough.
2. Why RDS is not publicly accessible, and the two independent controls keeping it that way.
3. Why the RDS security group references the EC2 security group instead of a CIDR block.
4. What managed RDS gives me over MySQL on EC2, and what I give up.
5. Multi-AZ versus a read replica, and which problem each one solves.
6. What happens during a failover, and why the app does not have to be told.
7. How an instance reads a secret with nothing stored on it.
8. Why the inline policy names one ARN, and what is wrong with `Resource: "*"`.
9. How Session Manager replaces SSH, and why that lets the instances have no inbound rule except
   80.
10. Why the Apache logs go to CloudWatch, and why the agent is configured in the launch template.
11. Which metric I would alarm on first in a real deployment, and why it is probably not CPU.
12. What is still a single point of failure here.

## Future Improvements

* Move the database connection into the application: read the secret at runtime, query on
  request, show the result on the page instead of proving it from a shell.
* Alarms on `UnHealthyHostCount >= 1`, on RDS `FreeStorageSpace` and `DatabaseConnections`, and
  a metric filter on the error log group.
* Encryption at rest on RDS with a customer managed KMS key.
* HTTPS on 443 with an ACM certificate, and a custom domain in Route 53.
* Tighter outbound rules, limited to what each tier actually needs.
* One NAT Gateway per AZ, so losing a zone does not take the other zone's outbound path with it.
* VPC endpoints for Secrets Manager, Systems Manager and CloudWatch, so the traffic never leaves
  the VPC and does not pay NAT data processing.
* A real backup retention window and a restore I have actually tested.
* A remote Terraform backend with state locking.

**In one sentence:** I built a three-tier architecture in a custom VPC across two Availability
Zones, with an internet-facing load balancer in public subnets, an Auto Scaling group of EC2
instances with no public IP in private ones, and a private Multi-AZ RDS MySQL instance in
database subnets with no Internet route, the tiers chained by security group references, the
password in Secrets Manager readable through a role scoped to that one secret, administration
through Session Manager instead of SSH and the Apache logs centralised in CloudWatch from the
launch template. The targets are healthy and I have run real queries against the database from
the application tier, so what is left is moving that connection into the application itself.
