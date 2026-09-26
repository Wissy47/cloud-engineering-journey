# Week 5 Day 2 — Launch Templates, Auto Scaling Groups, and Traffic-Based Scaling

## Objective

Build an Auto Scaling architecture that can automatically create, register, scale, and remove EC2 instances behind an Application Load Balancer.

The lab focused on:

* EC2 Launch Templates
* Auto Scaling Groups
* Desired, minimum, and maximum capacity
* Automatic instance launch and termination
* Automatic target-group registration
* Health checks
* Scaling out and scaling in
* Target tracking policies
* ALB request-based scaling concepts
* Troubleshooting emulator limitations in Floci

---

## Starting Architecture

Week 5 Day 1 already provided:

```text
Client
   |
   v
Application Load Balancer :80
   |
   v
Target Group
   |
   +---- Web Server A
   |
   +---- Web Server B
```

Those EC2 instances were launched manually.

The goal for Day 2 was to replace manual instance management with:

```text
Launch Template
       |
       v
Auto Scaling Group
       |
       v
EC2 Instances
       |
       v
Target Group
       |
       v
Application Load Balancer
```

---

## Core Auto Scaling Concepts

An Auto Scaling Group manages the number of EC2 instances running in an application.

Three important values control capacity:

```text
MinSize
DesiredCapacity
MaxSize
```

For this lab:

```text
MinSize:          2
DesiredCapacity:  2
MaxSize:          4
```

Meaning:

```text
Never run fewer than 2 instances.

Normally maintain the desired capacity.

Never scale beyond 4 instances.
```

---

## Launch Template

A Launch Template acts as a reusable blueprint for EC2 instances.

It defined:

* AMI
* Instance type
* Security Group
* User Data
* Instance tags

The existing custom AMI was reused:

```text
AMI:
ami-19e6ea348547095a9

Name:
week3-day4-cloud-lab-ami

Architecture:
arm64
```

Instance type:

```text
t4g.micro
```

Backend Security Group:

```text
sg-e57859fda5ead5e67
week5-backend-sg
```

---

## User Data

A bootstrap script was created to automatically start the web application on every ASG-created instance.

```bash
cat > /tmp/week5-asg-userdata.sh <<'EOF'
#!/bin/bash

mkdir -p /opt/week5-web

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id || hostname)

cat > /opt/week5-web/index.html <<HTML
<h1>Week 5 Auto Scaling Lab</h1>
<h2>Instance: ${INSTANCE_ID}</h2>
<p>Managed by an Auto Scaling Group</p>
HTML

cd /opt/week5-web

nohup python3 -m http.server 8080 --bind 0.0.0.0 \
  > /var/log/week5-web.log 2>&1 &
EOF
```

Each automatically launched instance therefore generated a page containing its unique Instance ID.

---

## User Data Encoding

Launch Template User Data was Base64 encoded.

```bash
USER_DATA_B64=$(base64 < /tmp/week5-asg-userdata.sh | tr -d '\n')
```

The encoded value was included in the Launch Template definition.

---

## Launch Template Configuration

The template contained:

```json
{
  "ImageId": "ami-19e6ea348547095a9",
  "InstanceType": "t4g.micro",
  "SecurityGroupIds": [
    "sg-e57859fda5ead5e67"
  ],
  "UserData": "<BASE64_USER_DATA>",
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {
          "Key": "Name",
          "Value": "week5-asg-web"
        }
      ]
    }
  ]
}
```

The Launch Template allowed the Auto Scaling Group to launch identical EC2 instances automatically.

---

## Auto Scaling Group

The Auto Scaling Group was created as:

```text
Name:
week5-web-asg

MinSize:
2

DesiredCapacity:
2

MaxSize:
4
```

Private subnets:

```text
subnet-9a4a8120
us-east-1a

subnet-9fb59c20
us-east-1b
```

The intention was to distribute instances across both Availability Zones.

---

## ASG Instance Discovery

Instance IDs were retrieved using:

```bash
ASG_INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names week5-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)
```

The result initially contained two instance IDs separated by a tab.

Passing this directly to:

```bash
aws ec2 describe-instances \
  --instance-ids "$ASG_INSTANCE_IDS"
```

caused:

```text
InvalidInstanceID.NotFound
```

because the shell treated both IDs as a single argument.

---

## Bash Array Fix

The instance IDs were instead stored in a Bash array:

```bash
ASG_INSTANCE_IDS=($(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names week5-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text))
```

All array elements could then be passed individually:

```bash
aws ec2 describe-instances \
  --instance-ids "${ASG_INSTANCE_IDS[@]}"
```

This demonstrated the difference between:

```text
Normal variable
=
one string
```

and:

```text
Bash array
=
multiple separate values
```

---

## Initial ASG Instances

The Auto Scaling Group initially launched:

```text
i-e5efafba8406d2d3a
i-76a5b461312fb9d3a
```

Both were:

```text
running
```

and tagged:

```text
Name = week5-asg-web
```

---

## Availability Zone Observation

Both instances were launched into:

```text
subnet-9a4a8120
us-east-1a
```

even though the Auto Scaling Group was configured with:

```text
subnet-9a4a8120
subnet-9fb59c20
```

The ASG configuration confirmed both subnets were stored:

```text
subnet-9a4a8120,subnet-9fb59c20
```

However:

```text
AvailabilityZones: []
```

was returned by Floci.

This showed a limitation in the local emulator's multi-AZ Auto Scaling placement behavior.

In real AWS, an ASG configured across multiple Availability Zones normally attempts to balance capacity across them.

---

## Initial Target Group Problem

The ASG instances were automatically registered with the existing Day 1 target group.

Health status showed:

```text
unhealthy
Target.FailedHealthChecks
```

The target group configuration was inspected:

```text
Protocol:
HTTP

Port:
80

HealthCheckPort:
traffic-port

HealthCheckPath:
/
```

The application, however, was running on:

```text
8080
```

This created:

```text
Target Group → Port 80
          X
Application → Port 8080
```

---

## New Target Group

A new target group was created specifically for ASG-managed instances.

```text
Name:
week5-asg-web-targets

Protocol:
HTTP

Port:
8080

Target Type:
instance

Health Check Port:
traffic-port

Health Check Path:
/
```

New Target Group ARN:

```text
arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/week5-asg-web-targets/061ae0291be145a7
```

---

## Attaching the Target Group

The initial attempt used:

```bash
aws autoscaling update-auto-scaling-group \
  --target-group-arns ...
```

This failed because:

```text
--target-group-arns
```

is not an option for:

```text
update-auto-scaling-group
```

The correct operation was:

```bash
aws autoscaling attach-load-balancer-target-groups \
  --auto-scaling-group-name week5-web-asg \
  --target-group-arns "$NEW_TARGET_GROUP_ARN"
```

This demonstrated that Auto Scaling target-group attachment is a separate operation.

---

## Target Group Verification

The target group attachment was verified:

```bash
aws autoscaling describe-load-balancer-target-groups \
  --auto-scaling-group-name week5-web-asg \
  --output table
```

Result:

```text
week5-asg-web-targets
State: InService
```

---

## Existing Instance Registration Behavior

The two instances that already existed before the new target group was attached were not automatically back-registered by Floci.

This demonstrated:

```text
ASG membership
!=
Target Group membership
```

An instance can be:

```text
Running
InService
Healthy in the ASG
```

while not being registered in a specific target group.

---

## Scale-Out Test

Desired capacity was changed from:

```text
2
```

to:

```text
3
```

using:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name week5-web-asg \
  --desired-capacity 3
```

The Auto Scaling Group automatically created:

```text
i-ba7ea7b81f5c9b519
```

The new instance initially appeared as:

```text
Pending
```

and later:

```text
InService
Healthy
```

---

## Automatic Target Registration

The newly created EC2 instance automatically appeared in the new target group.

This confirmed:

```text
ASG launches instance
        |
        v
Target Group registration
        |
        v
Health checks
```

without manually calling:

```text
register-targets
```

---

## Health Check Troubleshooting

The new target initially appeared as:

```text
unhealthy
Target.FailedHealthChecks
```

The application was inspected directly:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  ss -tulpn | grep 8080
```

Result:

```text
0.0.0.0:8080 LISTEN
python3
```

The web application was tested:

```bash
docker exec floci-ec2-i-ba7ea7b81f5c9b519 \
  curl -s http://127.0.0.1:8080
```

Response:

```html
<h1>Week 5 Auto Scaling Lab</h1>
<h2>Instance: i-ba7ea7b81f5c9b519</h2>
<p>Managed by an Auto Scaling Group</p>
```

This proved User Data had executed successfully.

---

## Health Check Logs

Application logs showed requests every approximately 30 seconds:

```text
"GET / HTTP/1.1" 200
```

This matched the target group's health-check interval.

After enough successful health checks, the target became:

```text
healthy
```

This demonstrated that an application may already be working before the load balancer officially marks it healthy.

---

## Scaling to Maximum Capacity

Desired capacity was increased to:

```text
4
```

The Auto Scaling Group launched:

```text
i-1093c1b54e1afea7b
```

The ASG then contained four instances:

```text
i-e5efafba8406d2d3a
i-76a5b461312fb9d3a
i-ba7ea7b81f5c9b519
i-1093c1b54e1afea7b
```

All were reported as:

```text
InService
Healthy
```

---

## New Instance Health Verification

For:

```text
i-1093c1b54e1afea7b
```

port 8080 was confirmed:

```text
0.0.0.0:8080 LISTEN
```

The application returned:

```html
<h1>Week 5 Auto Scaling Lab</h1>
<h2>Instance: i-1093c1b54e1afea7b</h2>
<p>Managed by an Auto Scaling Group</p>
```

Application logs again showed:

```text
GET / HTTP/1.1 200
```

from the health checker.

The target eventually transitioned from:

```text
unhealthy
```

to:

```text
healthy
```

---

## ASG Health vs Target Group Health

An important distinction was observed.

An ASG instance could show:

```text
InService
Healthy
```

while the target group showed:

```text
unhealthy
```

These statuses measure different things.

### Auto Scaling health

The ASG asks:

```text
Is the EC2 instance alive and acceptable to the Auto Scaling Group?
```

### Target Group health

The load balancer asks:

```text
Can the application be reached on the configured port and path,
and does it return the expected response?
```

Therefore:

```text
ASG Health
!=
Application Health
```

---

## Scale-In Test

Desired capacity was reduced from:

```text
4
```

back to:

```text
2
```

using:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name week5-web-asg \
  --desired-capacity 2
```

The Auto Scaling Group automatically terminated:

```text
i-e5efafba8406d2d3a
i-76a5b461312fb9d3a
```

The scaling activity reported:

```text
An instance was terminated in response to a desired capacity change.
```

Final instances:

```text
i-ba7ea7b81f5c9b519
i-1093c1b54e1afea7b
```

Both were:

```text
InService
Healthy
```

and both targets were:

```text
healthy
```

---

## Scaling Activities

Scaling history was inspected using:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name week5-web-asg \
  --max-items 10 \
  --output table
```

The history showed:

```text
Launching instance
Launching instance
Terminating instances
```

This is useful when troubleshooting why an ASG changed capacity.

---

# Traffic-Based Auto Scaling

The next goal was to scale based on actual application traffic instead of manually changing desired capacity.

The intended architecture was:

```text
Incoming Traffic
       |
       v
      ALB
       |
       v
RequestCountPerTarget
       |
       v
Target Tracking Policy
       |
       v
Auto Scaling Group
       |
       v
Desired Capacity changes automatically
```

---

## Target Tracking Policy

A target-tracking configuration was created using:

```text
ALBRequestCountPerTarget
```

A resource label was built from the ALB and target group:

```text
app/week5-web-alb/7c355d47fdd94ac2/targetgroup/week5-asg-web-targets/061ae0291be145a7
```

Configuration:

```json
{
  "TargetValue": 20.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ALBRequestCountPerTarget",
    "ResourceLabel": "app/week5-web-alb/7c355d47fdd94ac2/targetgroup/week5-asg-web-targets/061ae0291be145a7"
  }
}
```

The policy was created using:

```bash
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name week5-web-asg \
  --policy-name week5-alb-request-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration file:///tmp/week5-traffic-scaling.json
```

---

## Scaling Policy

Policy:

```text
Name:
week5-alb-request-tracking

Type:
TargetTrackingScaling

Target:
20 requests per target

Cooldown:
300 seconds
```

The scaling policy was successfully stored by Floci.

---

## How Request-Based Scaling Works

Conceptually:

```text
2 EC2 instances

100 requests per minute
        |
        v
100 / 2
        |
        v
50 requests per target
```

Target:

```text
20 requests per target
```

Since:

```text
50 > 20
```

the Auto Scaling system may increase capacity.

For example:

```text
2 -> 3 -> 4
```

As more instances are added:

```text
100 / 4
=
25 requests per target
```

which approaches the configured target.

When traffic falls, the system may scale back in.

The ASG still respects:

```text
MinSize = 2
MaxSize = 4
```

---

## CloudWatch Verification

CloudWatch alarms were checked:

```bash
aws cloudwatch describe-alarms \
  --output table
```

Result:

```text
No alarms returned
```

Application Load Balancer metrics were also checked:

```bash
aws cloudwatch list-metrics \
  --namespace AWS/ApplicationELB \
  --output table
```

Result:

```text
No metrics returned
```

---

## Floci Limitation

Floci successfully accepted and stored:

```text
TargetTrackingScaling
ALBRequestCountPerTarget
TargetValue = 20
```

However, it did not expose:

```text
AWS/ApplicationELB CloudWatch metrics
```

and did not create:

```text
CloudWatch alarms
```

Therefore automatic traffic-triggered EC2 scaling could not be demonstrated completely in the local environment.

The expected AWS flow is:

```text
ALB
 |
 v
CloudWatch metric
 |
 v
Target Tracking Policy
 |
 v
AWS Auto Scaling control loop
 |
 v
DesiredCapacity changes
```

The local environment successfully demonstrated the configuration and manual capacity lifecycle, while the CloudWatch-driven automatic control loop was limited by the emulator.

---

# Persistent Storage and Auto Scaling

An important architecture question was also explored:

```text
What happens if important data or a database is stored directly on an auto-scaled EC2 instance?
```

Auto Scaling instances should normally be treated as replaceable.

If an instance stores important local data and the ASG terminates it:

```text
Instance terminated
        |
        v
Local data may be lost
```

For production architectures, persistent state should generally be separated from the compute tier.

Typical services:

```text
Database
   -> RDS / Aurora

Object uploads
   -> S3

Shared filesystem
   -> EFS

Cache/session storage
   -> ElastiCache

Block storage
   -> EBS where appropriate
```

A typical architecture becomes:

```text
                 ALB
                  |
          -----------------
          |               |
        EC2             EC2
        ASG             ASG
          \               /
           \             /
              RDS
               |
              S3
```

The EC2 instances remain replaceable while persistent data survives instance replacement.

---

# Final Architecture

```text
                         Client
                           |
                           v
                 Application Load Balancer
                           |
                        HTTP :80
                           |
                           v
                    Target Group
                      HTTP :8080
                           |
                ---------------------
                |                   |
                v                   v
          ASG Instance        ASG Instance
             :8080               :8080
                \                   /
                 \                 /
                  Auto Scaling Group
                 Min=2 / Max=4
                        |
                        v
                  Launch Template
```

Target tracking was configured as:

```text
ALBRequestCountPerTarget
TargetValue = 20
```

---

# Key Concepts Learned

* Launch Templates define how Auto Scaling creates EC2 instances.
* Auto Scaling Groups manage desired capacity.
* `MinSize` prevents scaling below required capacity.
* `MaxSize` limits scale-out.
* `DesiredCapacity` represents the current capacity target.
* ASGs automatically launch replacement and additional instances.
* ASGs can automatically terminate excess capacity.
* New ASG instances can automatically register with target groups.
* Target Group health and ASG health are different concepts.
* Health-check thresholds cause a delay before targets become healthy.
* Target Group membership is different from ASG membership.
* Bash arrays are useful for handling multiple AWS resource IDs.
* Auto Scaling instances should normally be stateless.
* Persistent data should live outside the auto-scaled compute layer.
* Target tracking can scale capacity according to CloudWatch metrics.
* `ALBRequestCountPerTarget` can be used to scale web applications according to traffic.
* Local AWS emulators may not reproduce every AWS control-plane and data-plane behavior.
* Successful API configuration does not necessarily mean runtime automation is implemented.

---

# Commands Practiced

```bash
aws ec2 create-launch-template
aws ec2 describe-launch-templates
aws ec2 describe-launch-template-versions

aws autoscaling create-auto-scaling-group
aws autoscaling describe-auto-scaling-groups
aws autoscaling set-desired-capacity
aws autoscaling describe-scaling-activities

aws autoscaling attach-load-balancer-target-groups
aws autoscaling detach-load-balancer-target-groups
aws autoscaling describe-load-balancer-target-groups

aws autoscaling put-scaling-policy
aws autoscaling describe-policies

aws elbv2 create-target-group
aws elbv2 describe-target-groups
aws elbv2 describe-target-health

aws cloudwatch describe-alarms
aws cloudwatch list-metrics

docker exec
ss -tulpn
curl
```

---

# Final Result

Successfully implemented and tested:

```text
Launch Template                       ✅
Auto Scaling Group                    ✅
Minimum capacity                      ✅
Maximum capacity                      ✅
Desired capacity                      ✅
Automatic instance creation           ✅
Automatic instance termination        ✅
Automatic target registration         ✅
Application health checks             ✅
Scale out 2 -> 3 -> 4                 ✅
Scale in 4 -> 2                       ✅
Target Tracking policy creation       ✅
ALBRequestCountPerTarget configuration ✅
Traffic-triggered live scaling        Limited by Floci
```

