# Week 5 Day 5 — AMIs and Launch Templates Deep Dive

## Objective

Understand how Amazon Machine Images and Launch Templates work together to create repeatable EC2 deployments.

The lab focused on:

* Inspecting Launch Template configuration
* Decoding Launch Template User Data
* Understanding bootstrap vs baked-image approaches
* Creating a custom AMI from a configured instance
* Creating Launch Template versions
* Inheriting settings from an older template version
* Testing a new Launch Template version safely
* Understanding `LatestVersion` vs `DefaultVersion`
* Promoting and rolling back Launch Template versions
* Identifying how Floci AMI behavior differs from real AWS
* Demonstrating the baked-image concept using Docker

---

# Starting Point

The Auto Scaling Group from Week 5 Day 2 used:

```text
Launch Template:
week5-web-template
```

The existing template used:

```text
AMI:
ami-19e6ea348547095a9

Instance Type:
t4g.micro

Security Group:
sg-e57859fda5ead5e67

Name Tag:
week5-asg-web
```

The application itself was created and started using User Data.

---

# Bootstrap Model

The original deployment followed this model:

```text
Base AMI
   |
   v
Launch Template
   |
   v
EC2 instance starts
   |
   v
User Data executes
   |
   +-- creates application directory
   +-- creates HTML
   +-- determines instance ID
   +-- starts Python HTTP server
```

This is known as bootstrapping.

The machine starts from a relatively generic image and configures itself during launch.

---

# Baked Image Model

An alternative approach is to place more of the application inside the image before EC2 launches.

```text
Configured machine
      |
      v
Create AMI
      |
      v
AMI already contains:
  application
  runtime
  dependencies
  startup files
      |
      v
EC2 launches
```

User Data can then be much smaller.

---

# Bootstrap vs Baked AMI

```text
Bootstrap
--------------------------------
Generic image
More work at instance startup
Flexible configuration
Slower startup
More boot-time dependencies


Baked AMI
--------------------------------
Application already installed
Less work during startup
More consistent instances
Faster startup
Changes require a new image
```

A production architecture can use both:

```text
AMI
├── operating system
├── application runtime
├── common packages
└── application baseline

User Data
├── instance-specific configuration
├── environment configuration
├── secrets retrieval
└── service startup
```

---

# Inspect Launch Template Version 1

The Launch Template was discovered using:

```bash
LT_ID=$(aws ec2 describe-launch-templates \
  --launch-template-names week5-web-template \
  --query 'LaunchTemplates[0].LaunchTemplateId' \
  --output text)
```

Version 1 was inspected:

```bash
aws ec2 describe-launch-template-versions \
  --launch-template-id "$LT_ID" \
  --versions 1 \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData' \
  --output json
```

Configuration:

```text
ImageId:
ami-19e6ea348547095a9

InstanceType:
t4g.micro

SecurityGroupIds:
sg-e57859fda5ead5e67
```

User Data was stored as Base64.

---

# Decode User Data

Launch Template User Data was retrieved:

```bash
LT_USER_DATA=$(aws ec2 describe-launch-template-versions \
  --launch-template-id "$LT_ID" \
  --versions 1 \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData.UserData' \
  --output text)
```

Then decoded:

```bash
echo "$LT_USER_DATA" | base64 -d
```

The script created:

```text
/opt/week5-web
```

generated the instance-specific HTML page and started:

```text
python3 -m http.server 8080
```

This confirmed that Version 1 depended heavily on boot-time configuration.

---

# Preparing the Source Instance

A working ASG instance was selected:

```text
i-ba7ea7b81f5c9b519
```

It was stored as:

```bash
BAKE_INSTANCE_ID="i-ba7ea7b81f5c9b519"
```

The application directory was inspected:

```bash
docker exec floci-ec2-$BAKE_INSTANCE_ID \
  ls -lah /opt/week5-web
```

A reusable startup script was created:

```text
/usr/local/bin/week5-web-start
```

Its purpose was:

```text
change into application directory
start Python HTTP server on port 8080
write application logs
```

This represented configuration that would ideally be included inside a baked AMI.

---

# Create Baked AMI

A new AMI was created:

```bash
BAKED_AMI_ID=$(aws ec2 create-image \
  --instance-id "$BAKE_INSTANCE_ID" \
  --name "week5-day5-baked-web-ami" \
  --description "Week 5 Day 5 baked web application image" \
  --no-reboot \
  --query 'ImageId' \
  --output text)
```

Result:

```text
ami-2d8ea2f6d3baba1c1
```

The image was inspected:

```bash
aws ec2 describe-images \
  --image-ids "$BAKED_AMI_ID" \
  --query 'Images[0].[ImageId,Name,State,Architecture,Description]' \
  --output table
```

Result:

```text
AMI:
ami-2d8ea2f6d3baba1c1

Name:
week5-day5-baked-web-ami

State:
available

Architecture:
arm64
```

---

# Create Lightweight User Data

Launch Template v2 was designed to perform much less work at boot.

The script:

```bash
#!/bin/bash

INSTANCE_ID=$(curl -s \
  http://169.254.169.254/latest/meta-data/instance-id)

sed -i \
  "s/Instance: i-[a-zA-Z0-9]*/Instance: ${INSTANCE_ID}/" \
  /opt/week5-web/index.html

/usr/local/bin/week5-web-start
```

Instead of creating the application, it only:

```text
gets instance ID
updates instance-specific content
starts the preinstalled application
```

---

# Encode Version 2 User Data

The lightweight script was encoded:

```bash
V2_USER_DATA=$(base64 < /tmp/week5-v2-userdata.sh | tr -d '\n')
```

Launch Template override:

```json
{
  "ImageId": "ami-2d8ea2f6d3baba1c1",
  "UserData": "<BASE64_USER_DATA>"
}
```

---

# Create Launch Template Version 2

Version 2 was created based on Version 1:

```bash
LT_V2=$(aws ec2 create-launch-template-version \
  --launch-template-id "$LT_ID" \
  --source-version 1 \
  --version-description "Baked web AMI with lightweight bootstrap" \
  --launch-template-data file:///tmp/week5-template-v2.json \
  --query 'LaunchTemplateVersion.VersionNumber' \
  --output text)
```

Result:

```text
2
```

Using:

```text
--source-version 1
```

meant that Version 2 inherited:

```text
InstanceType
Security Groups
Tags
other existing template settings
```

while overriding:

```text
ImageId
UserData
```

---

# Launch Template Version 2

Version 2 contained:

```text
Version:
2

Default:
False

AMI:
ami-2d8ea2f6d3baba1c1

Instance Type:
t4g.micro

Security Group:
sg-e57859fda5ead5e67
```

This demonstrated non-destructive Launch Template versioning.

Version 1 remained available.

---

# Safe Test Deployment

Instead of immediately updating the Auto Scaling Group, Version 2 was tested by launching one standalone instance.

The first command attempted:

```bash
aws ec2 run-instances \
  --launch-template ... \
  --min-count 1 \
  --max-count 1
```

Floci returned:

```text
Unknown options:
--min-count
--max-count
```

The instance was successfully launched without those parameters:

```bash
TEST_INSTANCE_ID=$(aws ec2 run-instances \
  --launch-template "LaunchTemplateId=$LT_ID,Version=2" \
  --subnet-id subnet-9a4a8120 \
  --query 'Instances[0].InstanceId' \
  --output text)
```

Result:

```text
i-40ee84b61032104e7
```

---

# Verify Test Instance

The instance showed:

```text
Instance:
i-40ee84b61032104e7

State:
running

Image:
ami-2d8ea2f6d3baba1c1

Instance Type:
t4g.micro

Subnet:
subnet-9a4a8120
```

This confirmed Launch Template v2 was being used.

---

# Baked AMI Test Failure

The instance was inspected for the expected baked application:

```bash
docker exec floci-ec2-$TEST_INSTANCE_ID \
  ls -lah /opt/week5-web
```

Result:

```text
No such file or directory
```

The startup script was also missing:

```text
/usr/local/bin/week5-web-start
```

Port 8080 was not listening.

This demonstrated that Floci's `CreateImage` implementation did not preserve the modified source container filesystem in the same way a real AWS AMI would.

---

# Real AWS vs Floci AMI Behavior

On real AWS:

```text
Running EC2
   |
   v
Create AMI
   |
   v
Root EBS volume captured
   |
   v
New instance from AMI
   |
   v
Files remain present
```

In this Floci lab:

```text
CreateImage
   |
   v
AMI metadata created
   |
   v
new instance launched with AMI ID
   |
   X
modified container filesystem not preserved
```

This was identified as an emulator limitation.

---

# Demonstrating a True Baked Image with Docker

Because Floci EC2 instances ultimately use container images, Docker was used to demonstrate what a real baked machine image should contain.

A custom Docker image was built:

```text
week5-baked-web:v2
```

The image contained:

```text
/opt/week5-web/index.html
/usr/local/bin/week5-web-start
Python runtime
curl
```

Verification:

```bash
docker run --rm week5-baked-web:v2 \
  ls -lah /opt/week5-web
```

Result:

```text
index.html
```

Startup script:

```bash
docker run --rm week5-baked-web:v2 \
  cat /usr/local/bin/week5-web-start
```

The script was successfully present inside the image.

This demonstrated the real baked-image concept:

```text
Image already contains:
├── application files
├── runtime
├── dependencies
└── startup logic
```

---

# Launch Template Promotion

Launch Template state before promotion:

```text
LatestVersionNumber: 2
DefaultVersionNumber: 1
```

This demonstrated:

```text
Latest Version
=
newest version that exists

Default Version
=
version selected when $Default is requested
```

They do not have to be the same.

---

# Promote Version 2

Version 2 was promoted:

```bash
aws ec2 modify-launch-template \
  --launch-template-id "$LT_ID" \
  --default-version 2
```

Result:

```text
LatestVersionNumber: 2
DefaultVersionNumber: 2
```

Version 2 became the default configuration.

---

# Rollback to Version 1

Because Floci's custom AMI did not contain the expected baked filesystem, Version 2 was not safe for the working Auto Scaling Group.

The template was rolled back:

```bash
aws ec2 modify-launch-template \
  --launch-template-id "$LT_ID" \
  --default-version 1
```

Final state:

```text
LatestVersionNumber: 2
DefaultVersionNumber: 1
```

Version 2 remained available while Version 1 became active again.

---

# Safe Deployment Pattern

This lab demonstrated a useful deployment workflow:

```text
Launch Template v1
       |
       v
Create v2
       |
       v
Test v2 independently
       |
       v
Promote v2
       |
       v
Monitor
       |
       +------ success → keep v2
       |
       +------ failure → rollback to v1
```

The old template version is not overwritten.

This makes rollback significantly safer.

---

# Why Launch Template Versions Matter

Without versioning:

```text
configuration changed
        ↓
old configuration lost
```

With Launch Template versions:

```text
v1
v2
v3
v4
```

Different deployments can reference specific versions.

This provides:

```text
configuration history
controlled deployments
rollback capability
testing before promotion
repeatable infrastructure
```

---

# AMI vs Launch Template

A useful distinction:

```text
AMI
=
what the machine contains
```

Examples:

```text
OS
runtime
packages
application binaries
baseline configuration
```

Launch Template:

```text
how the machine should be launched
```

Examples:

```text
AMI ID
instance type
Security Groups
IAM profile
User Data
tags
metadata settings
```

Together:

```text
AMI
  +
Launch Template
  =
repeatable EC2 deployment
```

---

# Production Image Strategy

A common production approach is:

```text
Build
  |
  v
Install dependencies
  |
  v
Install application
  |
  v
Test
  |
  v
Create new AMI
  |
  v
Create Launch Template version
  |
  v
Test
  |
  v
Roll out
```

Tools such as image-building pipelines can automate this process.

---

# Immutable Infrastructure

This workflow introduces the idea of immutable infrastructure.

Instead of repeatedly modifying existing servers:

```text
SSH into server
change files
install packages
fix configuration
```

a new image can be built:

```text
AMI v1
   ↓
AMI v2
   ↓
AMI v3
```

Then old instances are replaced with instances using the newer image.

Benefits include:

```text
consistency
repeatability
easier rollback
less configuration drift
simpler scaling
```

---

# Floci Limitations Identified

```text
CreateImage API                 ✅
AMI metadata                    ✅
Launch instance from custom AMI ✅
Filesystem snapshot behavior    ❌
Create Launch Template version  ✅
Modify default version          ✅
Rollback template version       ✅
Docker baked-image simulation   ✅
```

---

# Key Concepts Learned

* AMIs define what software and files exist on an EC2 machine.
* Launch Templates define how EC2 instances are launched.
* User Data is useful for boot-time configuration.
* Baking applications into an AMI reduces launch-time work.
* Baked images can improve startup consistency.
* Launch Template versions are immutable configurations.
* New versions can inherit from older versions.
* Latest and Default Launch Template versions are different concepts.
* New versions should be tested before promotion.
* Rollback can be performed by changing the default version.
* Old Launch Template versions remain available after rollback.
* Immutable infrastructure reduces configuration drift.
* Local emulators may implement AMI metadata without reproducing real AWS filesystem snapshot behavior.

---

# Commands Practiced

```bash
aws ec2 describe-launch-templates
aws ec2 describe-launch-template-versions
aws ec2 create-image
aws ec2 describe-images
aws ec2 create-launch-template-version
aws ec2 modify-launch-template
aws ec2 run-instances
aws ec2 describe-instances

base64
docker build
docker run
docker exec
ls
cat
ss
curl
```

---

# Final Result

Successfully demonstrated:

```text
Inspect Launch Template v1       ✅
Decode User Data                  ✅
Create custom AMI                 ✅
Create Launch Template v2         ✅
Inherit settings from v1          ✅
Lightweight User Data concept     ✅
Test version independently        ✅
Identify Floci AMI limitation     ✅
Create true baked Docker image    ✅
Promote v2                        ✅
Rollback to v1                    ✅
Preserve version history          ✅
```

Final Launch Template state:

```text
Latest Version:  2
Default Version: 1
```
