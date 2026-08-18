# **Three-Tier Application with Private RDS**

## Goal

In project 3 I had a web tier that was already highly available: a load balancer in public
subnets, two EC2 instances in private subnets, an Auto Scaling group keeping them alive. But
the app stored nothing. There was no data to protect.

So here I added a database, and that changes everything about the security design. The
architecture becomes three tiers: the load balancer as the public entry point, the EC2
instances in the middle, RDS MySQL at the bottom. Each tier only talks to the one next to it.

The database sits in its own pair of subnets with no route to the Internet, accepts connections
only from the application security group, and its master password is never written down
anywhere. It lives in Secrets Manager and the instances read it through an IAM role.

I built everything by hand in the AWS Console in `eu-west-2` first, so I understood each piece
before automating it. The same architecture is then written as Terraform in
[`terraform/`](terraform/).

## Architecture

![AWS architecture](architecture-diagram.png)

```text
Internet
   |
Internet Gateway
   |
Application Load Balancer
Public subnet A / Public subnet B
   |
Target group
   |
Auto Scaling group
   |
EC2 A / EC2 B
Private app subnet A / Private app subnet B
   |
TCP 3306
   |
Amazon RDS for MySQL
Private DB subnet A / Private DB subnet B
```

Two things in the diagram are not what I deployed, and I would rather say it than let the
picture speak for me:

* **Route 53** is marked *Optional*. I have no custom domain here. The app is reached on the
  DNS name of the load balancer.
* The legend shows **443** on the ALB security group and **restrictive outbound rules**. Neither
  is true: my listener is HTTP on port 80, and I left the outbound rules at the AWS default
  while building and testing.

Everything else is running, including the Multi-AZ database with its standby in the second
Availability Zone.

## Repository Layout

```text
.
├── README.md                            this file: the architecture and what I verified
├── architecture-diagram.png
├── user-data/
│   ├── install-apache.sh                the first bootstrap script
│   ├── install-apache-cloudwatch.sh     the current one: same thing plus the CloudWatch Agent
│   └── amazon-cloudwatch-agent.json     the agent config on its own, easier to read
└── terraform/                           the same architecture as Infrastructure as Code
    └── README.md                        how to run it, file by file
```

## AWS Services Used

* **Amazon VPC** for the network: six subnets, three route tables, the gateways.
* **Application Load Balancer** as the only public entry point, across both AZs.
* **EC2 and EC2 Auto Scaling** for the application tier.
* **Amazon RDS for MySQL** for the database, private and Multi-AZ.
* **AWS Secrets Manager** for the master credentials, created and managed by RDS.
* **AWS IAM** for the instance role, with one inline policy scoped to one secret.
* **AWS Systems Manager** for Session Manager, so I never open port 22.
* **Amazon CloudWatch** for metrics, the CPU alarm and the Apache log groups.
* **Amazon SNS** for the alarm notification, with an email subscription.
* **NAT Gateway** and **Internet Gateway** for outbound and inbound Internet access.

## Network Design

The VPC covers two Availability Zones and is split into three pairs of subnets, one pair per
tier:

| Subnets | What lives there | Route for `0.0.0.0/0` |
|---|---|---|
| 2 public | ALB nodes, NAT Gateway | Internet Gateway |
| 2 private app | the EC2 instances | NAT Gateway |
| 2 private DB | the RDS DB subnet group | **none** |

Six subnets instead of four, because of that third route table. The instances need outbound
Internet access: they install packages at first boot, the SSM agent has to reach Systems
Manager, and the app calls Secrets Manager and CloudWatch. So their route table points
`0.0.0.0/0` at the NAT Gateway.

The database needs none of that. Its route table only has the local VPC route. RDS cannot start
a connection to the Internet from there, and nothing on the Internet can reach it, whatever a
security group says.

RDS also requires a DB subnet group with subnets in at least two AZs, because that is where it
puts the standby. In my case that is not hypothetical: the instance is Multi-AZ and the standby
runs in the second database subnet.

The EC2 instances have no public IPv4 address and no public DNS name. Neither does RDS:
`Publicly accessible` is set to No, so the endpoint only resolves to a private address inside
the VPC.

## Security Design

Three security groups, chained. Each one names the previous group as its source instead of an
IP range:

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

The ALB security group is the only one that mentions `0.0.0.0/0`. It is the perimeter.

The EC2 security group allows port 80 only from the ALB security group. Nothing that did not
come through the load balancer gets in. There is no path from the Internet to those subnets
anyway, but the two controls are independent and I want both.

The RDS security group allows TCP 3306 only from the EC2 security group. Not from a CIDR block,
not from my laptop.

Referencing a security group instead of an address is what makes this work with Auto Scaling.
Instances get replaced and private IPs change, but the rule keeps meaning "whatever is running
in the application tier right now".

Security groups are stateful, which is why none of these rules has a matching reply rule. The
response to an allowed inbound connection goes back out automatically.

**On outbound rules, honestly:** I left them permissive, which is the AWS default. A hardened
version would limit the instances to 3306 towards the RDS security group plus 443 for the AWS
endpoints, and the ALB to port 80 towards the instances. I have not done it, so I am not
claiming it.

Port 22 is closed everywhere and there is no key pair on the launch template. I administer the
instances with **Session Manager**, which works over the SSM agent's outbound connection and
needs no inbound rule at all.

## Application Tier

The launch template describes an instance: Amazon Linux, the EC2 security group, the instance
profile, the User Data. No key pair, and no subnet.

Leaving the subnet out is deliberate. Picking where an instance goes is the Auto Scaling group's
job, and that is what spreads the instances over the two zones.

The first version of the script,
[`user-data/install-apache.sh`](user-data/install-apache.sh), installs Apache, enables it and
writes a test page. The current one,
[`user-data/install-apache-cloudwatch.sh`](user-data/install-apache-cloudwatch.sh), does the
same and adds the CloudWatch Agent. I kept both files because the second only makes sense next
to the first.

User Data runs once, at the first boot. It is provisioning, not configuration management.
Editing the script does nothing to the instances already running, only to the ones launched
after the change. That is why adding the agent meant a new template version and an instance
refresh, not an edit on the running instances.

The Auto Scaling group runs across the two private application subnets: min 2, desired 2, max 4.
It registers its instances in the target group by itself.

One naming detail I am documenting instead of hiding. My Auto Scaling group is called
**`project4-launch-template`**. That is the name the console suggested when I created the group
from the template, and it looks like a launch template name. It is the Auto Scaling group. The
CloudWatch alarm further down uses that same name, because that is what the group is called.

The load balancer has an HTTP listener on 80 forwarding to the target group
**`project4-web-tg`**: target type *Instances*, protocol HTTP, port 80, health check on `/`.
The target group is not a server and not a hop in the path. It is the list of backend targets
plus the health check that decides which of them the load balancer may use.

## Database Tier

| Setting | Value | Why |
|---|---|---|
| Engine | MySQL Community Edition | the default relational engine at SAA level |
| Class | `db.t4g.micro` | smallest burstable Graviton class, cheapest thing that runs |
| Storage | General Purpose SSD (gp3) | no Provisioned IOPS, this lab has no IO profile |
| Deployment | **Multi-AZ** | a standby in the second zone, so a zone failure is a failover |
| Public access | No | the endpoint only resolves inside the VPC |
| Subnet group | the two private DB subnets | required by RDS, and where the standby lives |
| Credentials | managed in Secrets Manager | see below |

The question I care about is not how to create the database. It is what RDS gives me that MySQL
on an EC2 instance would not: backups, patching, failover, storage and metrics become the
service's problem instead of mine. What I lose is root on the host. No shell on the database
server, only parameters and an endpoint.

Multi-AZ is availability, not performance. The standby serves no traffic and I cannot read from
it. It receives the writes synchronously and sits there so that a failure promotes it, with the
endpoint pointing at the new instance. The application never finds out, because all it ever
knows is the endpoint. Read replicas are the other tool, asynchronous and readable, and they
solve a different problem.

## Secrets Manager and IAM

The master password is not in the code, not in User Data, not in this repository and not in a
config file. RDS created the secret and manages it in **Secrets Manager**, and the application
reads it at runtime.

The instances get permission through the role **`project4-ec2-role`**, attached to the launch
template as an instance profile:

* `AmazonSSMManagedInstanceCore`, for Session Manager.
* `CloudWatchAgentServerPolicy`, for the CloudWatch Agent.
* one **inline policy**, which is the part that matters:

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

The `Resource` is the ARN of that one secret, not `*`. If the account ends up with twenty
secrets, these instances can still read exactly one of them. Least privilege as a line in a
policy document rather than a principle in a slide.

```text
EC2 instance
   → instance profile → project4-ec2-role
   → temporary credentials from the instance metadata service
   → secretsmanager:GetSecretValue on one specific secret ARN
```

There is no IAM user, no access key and no password stored on the instances. The credentials
they use are temporary and rotated by AWS.

I tested this instead of assuming it. From a **Session Manager** shell on one of the instances
(no SSH, no key pair, no inbound rule) I read the secret with the instance role, connected to
the RDS endpoint with the MySQL client and ran queries against the database. That one test
covers the whole chain: the instance profile, the inline policy, the outbound path to the AWS
endpoints, the private DNS resolution of the RDS endpoint and the 3306 rule.

## Observability

What is running:

* **CloudWatch metrics.** EC2 publishes `CPUUtilization` and the rest of the standard set on its
  own. I checked the metric for the Auto Scaling group `project4-launch-template` in the
  console.
* **A CloudWatch alarm** on `CPUUtilization`, namespace `AWS/EC2`, dimension
  `AutoScalingGroupName = project4-launch-template`, statistic Average, period 5 minutes,
  threshold **> 70%**.
* **An SNS topic `project4-alerts`** with an email subscription. The alarm publishes to it when
  it goes into ALARM.

```text
EC2 / Auto Scaling group
   ├── metrics ──→ CloudWatch metrics ──→ alarm (CPU > 70%) ──→ SNS project4-alerts ──→ email
   └── Apache logs ──→ CloudWatch Logs (one stream per instance, next section)
```

Other services publish their own metrics, and having them is not the same as monitoring them. I
built **no** alarms on any of these:

* **ALB**: `RequestCount`, `TargetResponseTime`, `HTTPCode_ELB_5XX_Count`,
  `HTTPCode_Target_5XX_Count`, `ActiveConnectionCount`.
* **Target group**: `HealthyHostCount`, `UnHealthyHostCount`. In a real deployment
  `UnHealthyHostCount >= 1` is the alarm I would want before a CPU one.
* **RDS**: `CPUUtilization`, `DatabaseConnections`, `FreeStorageSpace`, `FreeableMemory`,
  `ReadLatency` and `WriteLatency`, `BurstBalance`.
* **EC2**: memory and disk usage are not in the standard set. They need the CloudWatch Agent,
  because the hypervisor cannot see inside the instance.

## CloudWatch Logs

The Apache logs of every instance go to CloudWatch Logs through the CloudWatch Agent, which the
instance role can use because it carries `CloudWatchAgentServerPolicy`.

This matters more here than anywhere else in the project. The Auto Scaling group can terminate
an instance at any moment, and `/var/log/httpd/` goes with it. Centralising the logs means what
happened outlives the instance it happened on.

```text
EC2 A ──┐
        ├──→ /project4/apache/access   stream: <instance-id>
EC2 B ──┘    /project4/apache/error    stream: <instance-id>
```

Two log groups, one per log file, one stream per instance inside each. The stream name comes
from the `{instance_id}` placeholder, which the agent expands at runtime, so a brand new
instance gets its own stream without anyone configuring it.

The important part: **the configuration lives in the launch template, not on the instances.**
Installing the agent by hand over Session Manager would work right up until the next instance
replacement, then quietly stop working on the new one.

How I applied it, in order:

1. [`user-data/install-apache-cloudwatch.sh`](user-data/install-apache-cloudwatch.sh) is the
   original script plus three things: `amazon-cloudwatch-agent` in the `dnf install` line, the
   agent config written to
   `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`, and the
   `amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:... -s` call that loads it and
   starts the agent.
2. **EC2 → Launch templates → Actions → Modify template (create new version)**, with that
   script in *Advanced details → User data*. New version set as the default.
3. **Auto Scaling groups → project4-launch-template → Edit**, group pointing at `$Latest`.
4. An **instance refresh** with minimum healthy percentage 50, so one instance keeps serving
   while the other is replaced. That is the whole reason for having two of them.
5. **CloudWatch → Log groups**: `/project4/apache/access` and `/project4/apache/error` appear
   when the agent first writes, each with one stream per instance ID.
6. Traffic sent to the load balancer DNS name shows up in the access log stream.

One thing to watch: the agent asks for a 7 day retention when it creates a group, but retention
is not applied retroactively to a group that already exists. If the group was created earlier,
set it in the console. The Terraform here avoids the problem by declaring both log groups with
their retention instead of letting the agent create them.

## Traffic Flow

Inbound, from a client:

```text
Client
→ Internet Gateway
→ Application Load Balancer   (public subnets, ALB security group)
→ Target group                (healthy targets only)
→ EC2 instance                (private app subnet, port 80 from the ALB security group)
→ RDS endpoint                (private DB subnet, port 3306 from the EC2 security group)
```

Outbound, from an instance:

```text
EC2 instance
→ private app route table (0.0.0.0/0 → NAT Gateway)
→ NAT Gateway             (public subnet, Elastic IP)
→ Internet Gateway
→ Internet and AWS endpoints (Systems Manager, Secrets Manager, CloudWatch)
```

From the database:

```text
RDS instance
→ DB route table (local VPC route only)
→ nowhere
```

## How I Built It

The order comes from the dependencies between the pieces:

1. VPC, then the six subnets across two Availability Zones.
2. Internet Gateway attached to the VPC, then the NAT Gateway with its Elastic IP in a public
   subnet.
3. The three route tables (public to the Internet Gateway, application to the NAT Gateway,
   database with no `0.0.0.0/0` route) and their subnet associations.
4. The three security groups. ALB first, because the EC2 one references it, and EC2 before RDS
   for the same reason.
5. DB subnet group over the two private DB subnets, then the Multi-AZ RDS MySQL instance with
   `Publicly accessible = No` and credentials managed in Secrets Manager.
6. The role `project4-ec2-role` with the two managed policies and the inline policy scoped to
   the secret ARN. It has to exist before the launch template that references it.
7. Target group `project4-web-tg`, then the internet-facing load balancer in the two public
   subnets with an HTTP:80 listener forwarding to it.
8. Launch template, then the Auto Scaling group across the two private application subnets,
   attached to the target group.
9. SNS topic `project4-alerts` and the email subscription, confirmed from the email before it
   can receive anything, then the CloudWatch alarm pointing at it.
10. A new launch template version with the CloudWatch Agent in the User Data, and an instance
    refresh so the running instances were replaced by ones that configure the agent themselves.

## Current Validation Status

What I actually checked:

* the Auto Scaling group created the instances itself, in the two private application subnets;
* neither instance has a public IPv4 address, which is the point of those subnets;
* both were registered in `project4-web-tg` automatically and the target group reported them
  **Healthy**, so the load balancer can route to the application tier;
* RDS is private, not publicly accessible, and running **Multi-AZ** with the standby in the
  second zone;
* the RDS security group allows TCP 3306 only from the EC2 security group;
* Secrets Manager holds the RDS-managed credentials and the instances carry
  `project4-ec2-role`;
* **the database answers queries.** From a Session Manager shell on an instance I read the
  secret with the role, connected to the RDS endpoint and ran queries. The whole chain works,
  not just exists;
* Session Manager itself works, with no key pair and no rule on port 22;
* CloudWatch receives `CPUUtilization` for the Auto Scaling group;
* the CPU alarm exists and is wired to `project4-alerts`;
* the CloudWatch Agent is configured from the launch template, and both log groups receive the
  Apache logs with one stream per instance ID.

What I have not done yet:

* **the web page does not talk to the database.** The instances serve a static test page. I made
  the connection by hand from the instance, not from application code. Turning that into a page
  that queries the database and shows the result is the piece still missing.
* I have not fired the CPU alarm on purpose, so I have not seen the email arrive.
* I have not tested failure behaviour: terminating an instance to watch the group replace it,
  stopping Apache to see a target go unhealthy, or rebooting RDS with failover to see how long
  the endpoint takes to follow the standby.

So the infrastructure is built, isolated the way I wanted, and proven tier by tier up to a real
MySQL session from the application tier. What is missing is application code doing the same
thing on every request.

## Cleanup

Nothing here is covered by a free allowance the way project 1 was. The NAT Gateway costs per
hour plus data processed, the load balancer costs per hour whether it gets traffic or not, and
RDS costs per hour twice over because Multi-AZ runs a standby. Storage and backups are charged
even when the instance is stopped, and a stopped RDS instance restarts itself after seven days.
I delete everything the same day I build it.

Order matters:

1. Delete the **Auto Scaling group first**, or it will replace the instances I terminate.
2. Delete the load balancer, then the target group.
3. Delete the **RDS instance**, skipping the final snapshot for a lab, then the DB subnet group.
4. Delete the **NAT Gateway**, then release its Elastic IP. An unattached Elastic IP is billed
   on its own.
5. Delete the launch template, the security groups, the route tables, the subnets, the Internet
   Gateway, and last the VPC.
6. Delete the CloudWatch alarm, the two log groups, the SNS topic and its subscription.
7. Delete the Secrets Manager secret. It is scheduled for deletion with a recovery window
   rather than removed straight away, which is worth knowing before wondering why it is still
   in the list.
8. Check that no instance, orphan EBS volume or snapshot is left behind.

## What I Learned

* Three tiers is not three groups of servers, it is three blast radiuses. What makes the
  database a tier is that its route table has no way out and its security group names one
  source.
* A DB subnet group has to span two AZs before you can ask for a standby, because that is where
  AWS puts it.
* Multi-AZ is availability, not performance. The standby answers nothing.
* The application never learns that a failover happened. It knows an endpoint, and the endpoint
  is what moves.
* Chaining security groups by reference instead of by CIDR is what makes a rule survive an
  instance being replaced.
* A secret is only as private as the policy that reads it. Putting a password in Secrets Manager
  and then granting `GetSecretValue` on `*` throws most of the benefit away.
* An instance profile is how an EC2 instance receives a role, and the credentials it gets are
  temporary. There is nothing on disk to steal.
* Instance logs are as disposable as the instance. If the Auto Scaling group can terminate it,
  the logs have to leave it.
* Configuring an agent by hand over Session Manager works exactly until the next instance
  replacement. The reproducible place for it is the launch template.
* Standard EC2 metrics stop at the hypervisor. CPU is free, memory and disk need an agent
  inside the instance.

## What I Need to Be Able to Explain

1. What the third pair of subnets buys me, and why four subnets would not have been enough.
2. Why RDS is not publicly accessible, and the two independent controls that keep it that way.
3. Why the RDS security group references the EC2 security group instead of a CIDR block.
4. What managed RDS gives me over MySQL on EC2, and what I give up.
5. The difference between Multi-AZ and a read replica, and which problem each one solves.
6. What actually happens during a failover, and why the application does not have to be told.
7. How an EC2 instance reads a secret with nothing stored on it, from the instance profile to
   the temporary credentials.
8. Why the inline policy names one secret ARN, and what would be wrong with `Resource: "*"`.
9. How Session Manager replaces SSH, and why that lets the instances have no inbound rule
   except port 80.
10. Why the Apache logs go to CloudWatch Logs, and why the agent is configured in the launch
    template rather than on the instances.
11. Which metric I would alarm on first in a real deployment, and why it is probably not CPU.
12. What is still a single point of failure in this architecture.

## Future Improvements

* Move the database connection into the application: read the secret at runtime, query on
  request, show the result on the page instead of proving it from a shell.
* Alarms on `UnHealthyHostCount >= 1`, on RDS `FreeStorageSpace` and `DatabaseConnections`, and
  a metric filter on the error log group so a spike of 5xx raises something.
* Encryption at rest on RDS, with a customer managed KMS key.
* An HTTPS listener on 443 with a certificate from ACM, and a custom domain in Route 53 in front
  of the load balancer.
* Tighter outbound security group rules, limited to what each tier actually needs.
* One NAT Gateway per Availability Zone, so losing a zone does not take the outbound path of the
  other one with it.
* VPC endpoints for Secrets Manager, Systems Manager and CloudWatch, so that traffic never
  leaves the VPC and does not pay NAT Gateway data processing.
* A real backup retention window and a restore I have actually tested.
* A remote Terraform backend with state locking instead of local state.

**In one sentence:** I built a three-tier architecture in a custom VPC across two Availability
Zones, with an internet-facing load balancer in public subnets, an Auto Scaling group of EC2
instances with no public IP in private application subnets, and a private Multi-AZ RDS MySQL
instance in database subnets with no Internet route, the tiers chained by security group
references, the database password in Secrets Manager readable through an IAM role scoped to
that one secret, administration through Session Manager instead of SSH, and the Apache logs
centralised in CloudWatch Logs from the launch template. The targets are healthy behind the
load balancer and I have run real queries against the database from the application tier, so
what is left is moving that connection into the application itself.
