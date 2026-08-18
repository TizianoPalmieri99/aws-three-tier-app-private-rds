#!/bin/bash
# Bootstrap of the application tier, as it was deployed from the Console.
# Runs once, at the first boot of an instance created by the Auto Scaling group.

dnf update -y
dnf install -y httpd

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
