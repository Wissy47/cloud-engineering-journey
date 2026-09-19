# Inspect available AMIs
aws ec2 describe-images \
  --query 'Images[*].[ImageId,Name,Architecture,State]' \
  --output table

# Create User Data script
cat > /tmp/week3-day2-userdata.sh <<'EOF'
#!/bin/bash

echo "Week 3 Day 2 User Data executed successfully" \
  > /tmp/week3-day2-userdata.txt

mkdir -p /opt/cloud-lab

cat > /opt/cloud-lab/index.html <<'HTML'
<h1>Cloud Engineering Journey</h1>
<p>Week 3 Day 2 - EC2 User Data</p>
HTML
EOF

# Inspect User Data script
cat /tmp/week3-day2-userdata.sh

# Launch EC2 with User Data
USERDATA_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-ubuntu2404-arm64 \
  --instance-type t4g.micro \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --security-group-ids "$WEB_SG_ID" \
  --user-data file:///tmp/week3-day2-userdata.sh \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "$USERDATA_INSTANCE_ID"

# Inspect instance
aws ec2 describe-instances \
  --instance-ids "$USERDATA_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].[InstanceId,ImageId,InstanceType,State.Name,SubnetId]' \
  --output table

# Find Floci container
docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}' \
  | grep "$USERDATA_INSTANCE_ID"

# Enter container
docker exec -it <container-id> bash

# Verify User Data output
cat /tmp/week3-day2-userdata.txt
cat /opt/cloud-lab/index.html

# Add manual modification
echo "Manual change after first boot" \
  >> /tmp/week3-day2-userdata.txt

cat /tmp/week3-day2-userdata.txt

# Reboot instance
aws ec2 reboot-instances \
  --instance-ids "$USERDATA_INSTANCE_ID"

# Check CPU architecture inside instance
uname -m
arch
lscpu
returned:

aarch64

The arch command also returned:

aarch64

lscpu confirmed:

Architecture: aarch64

The AMI architecture should be compatible with the instance type architecture.

Example:

ARM64 AMI
+
ARM-based instance type
=
compatible

In real AWS:

t4g instances use AWS Graviton processors.

In this Floci lab, lscpu reported Apple as the CPU vendor because the Docker-backed instance runs locally on Apple Silicon.

User Data

User Data provides startup instructions when launching an EC2 instance.

It is commonly used to:

Install software
Create files
Configure services
Start applications
Bootstrap a new server
User Data Script

A local script was created at:

/tmp/week3-day2-userdata.sh

The script created:

/tmp/week3-day2-userdata.txt

and:

/opt/cloud-lab/index.html

User Data Launch

The instance was launched using:

AMI
+
Instance Type
+
User Data

Instance:

i-37b688abad3857c2f

AMI:

ami-ubuntu2404-arm64

Instance type:

t4g.micro

file:// URI

The User Data file was passed using:

file:///tmp/week3-day2-userdata.sh

Explanation:

file://
+
/tmp/week3-day2-userdata.sh
=
file:///tmp/week3-day2-userdata.sh

The AWS CLI reads the contents of the local file and sends them as User Data.

User Data Verification

Inside the instance:

cat /tmp/week3-day2-userdata.txt

returned:

Week 3 Day 2 User Data executed successfully

The HTML file also existed:

cat /opt/cloud-lab/index.html

and contained the expected custom content.

Reboot Test

A manual line was added:

Manual change after first boot

The EC2 instance was rebooted.

After reboot, both lines remained.

This demonstrated that the User Data script did not normally rerun during a standard reboot.

Key Lesson

Typical behavior:

Initial launch
→ User Data executes

Normal reboot
→ User Data normally does not execute again

User Data should therefore be thought of primarily as launch-time bootstrapping rather than an every-boot startup script.

Floci Persistence Troubleshooting

An earlier test instance disappeared from the Floci EC2 API while its Docker container remained running.

The cause was traced to starting Floci without persistent storage.

Floci was restarted using persistent storage, and persistence was successfully verified before rebuilding the lab.

This reinforced the distinction between:

AWS-style control-plane metadata
Docker-backed runtime state
Local emulator persistence
Key Concepts Learned
AMI = instance template
Instance type = compute profile
User Data = startup/bootstrap automation
ARM64 is also called aarch64
AMI and instance CPU architectures must be compatible
User Data normally runs during initial launch
User Data does not normally rerun on a standard reboot