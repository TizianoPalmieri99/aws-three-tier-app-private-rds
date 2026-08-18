#!/bin/bash
# Bootstrap of the application tier, with the CloudWatch Agent added.
#
# Same script as install-apache.sh, plus the agent that ships the Apache logs
# to CloudWatch Logs. This is the version that has to be put in a new launch
# template version so that every instance the Auto Scaling group creates from
# now on configures itself: the agent is never installed by hand on an
# instance, because that instance can be terminated and replaced at any time.
#
# The agent needs no credentials. It uses the instance profile, which carries
# the CloudWatchAgentServerPolicy managed policy.

dnf update -y
dnf install -y httpd amazon-cloudwatch-agent

systemctl enable httpd
systemctl start httpd

cat <<'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Project 4</title>
</head>
<body>
    <h1>Project 4 - Three-Tier Application with Private RDS</h1>
    <p>Web server running successfully.</p>
</body>
</html>
EOF

# Agent configuration. It is written to the path the agent reads by default.
# {instance_id} is expanded by the agent itself at runtime, so every instance
# writes to its own log stream inside the shared log groups.
cat <<'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/project4/apache/access",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/project4/apache/error",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
EOF

# -s starts the agent straight away; the unit is also enabled so it comes back
# after a reboot.
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

systemctl enable amazon-cloudwatch-agent
