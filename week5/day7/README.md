# Week 5 Day 7 — Mini-Project: Highly Available Auto-Scaled Web Architecture

## Objective

Validate the complete Week 5 architecture as one production-style system.

The mini-project combined:

- VPC networking
- Public and private subnets
- Application Load Balancer
- Target Group
- Auto Scaling Group
- Launch Template
- Security Groups
- Health Checks
- Automatic instance replacement
- Failure recovery
- Load distribution
- High availability

The goal was to prove that the application could remain available even when one backend EC2 instance failed.

---

# Architecture

```text
                         Internet
                            |
                            v
                  Application Load Balancer
                     Public Subnet A
                     Public Subnet B
                            |
                            v
                       Target Group
                        HTTP :8080
                         /      \
                        /        \
                       v          v
                    EC2 A        EC2 B
                 Private A     Private B
                       \          /
                        \        /
                    Auto Scaling Group
                  Min=2 Desired=2 Max=4
                            |
                            v
                    Launch Template
```

The EC2 instances are not accessed directly by clients.

Traffic reaches the application through the ALB.

---

# Initial Auto Scaling State

The Auto Scaling Group was inspected:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names week5-web-asg \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState,HealthStatus]]' \
  --output json
```

Result:

```text
MinSize:          2
DesiredCapacity:  2
MaxSize:          4
```

Initial healthy instances:

```text
i-1093c1b54e1afea7b
i-e0963642ea8f2bb81
```

Both were:

```text
InService
Healthy
```

---

# Target Group Health

The Target Group was checked:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$NEW_TARGET_GROUP_ARN" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

Result:

```text
i-1093c1b54e1afea7b   healthy
i-e0963642ea8f2bb81   healthy
```

This confirmed both instances were healthy at the application layer.

---

# Verify Load Balancing

The ALB was tested repeatedly:

```bash
for i in {1..6}; do
  curl -s "$ALB_URL" | grep 'Instance:'
done
```

Traffic alternated between:

```text
i-1093c1b54e1afea7b
i-e0963642ea8f2bb81
```

Example:

```text
Instance: i-1093c1b54e1afea7b
Instance: i-e0963642ea8f2bb81
Instance: i-1093c1b54e1afea7b
Instance: i-e0963642ea8f2bb81
```

This confirmed:

```text
Client
  |
  v
ALB
  |
  v
Target Group
  |
  +---- EC2 A
  |
  +---- EC2 B
```

---

# Failure Simulation

One Auto Scaling managed instance was deliberately terminated.

The purpose was to simulate unexpected EC2 failure while keeping:

```text
DesiredCapacity = 2
```

The expected behavior was:

```text
Desired = 2
Actual = 1
     |
     v
ASG detects missing capacity
     |
     v
ASG launches replacement
```

---

# Application Behavior During Failure

Immediately after the failure, requests were sent through the ALB:

```bash
for i in {1..10}; do
  curl -s "$ALB_URL" | grep 'Instance:'
done
```

All requests were handled by:

```text
i-e0963642ea8f2bb81
```

Example:

```text
Instance: i-e0963642ea8f2bb81
Instance: i-e0963642ea8f2bb81
Instance: i-e0963642ea8f2bb81
Instance: i-e0963642ea8f2bb81
```

This demonstrated graceful degradation.

Instead of the application becoming unavailable, the surviving healthy instance handled all traffic.

Conceptually:

```text
Before failure

ALB
├── EC2 A
└── EC2 B


After EC2 A fails

ALB
└── EC2 B
```

The application remained available.

---

# Auto Scaling Replacement

The Auto Scaling Group launched a replacement instance automatically.

New instance:

```text
i-b9e9f0e8b032c4f7b
```

The replacement instance:

```text
launched
started the application
registered with the target group
passed health checks
```

---

# Target Group After Recovery

The Target Group was checked again:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$NEW_TARGET_GROUP_ARN" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

Result:

```text
i-e0963642ea8f2bb81   healthy
i-b9e9f0e8b032c4f7b   healthy
```

The system had returned to two healthy backend instances.

---

# Load Balancing After Recovery

The ALB was tested again:

```bash
for i in {1..10}; do
  curl -s "$ALB_URL" | grep 'Instance:'
done
```

Traffic alternated between:

```text
i-e0963642ea8f2bb81
i-b9e9f0e8b032c4f7b
```

Example:

```text
Instance: i-e0963642ea8f2bb81
Instance: i-b9e9f0e8b032c4f7b
Instance: i-e0963642ea8f2bb81
Instance: i-b9e9f0e8b032c4f7b
```

This confirmed that the new replacement instance became a fully functioning backend.

---

# Complete Failure Recovery Flow

```text
Two healthy instances
        |
        v
One instance fails
        |
        v
ALB stops sending traffic to failed instance
        |
        v
Surviving instance handles all requests
        |
        v
ASG detects capacity below desired state
        |
        v
Replacement EC2 instance launches
        |
        v
Launch Template configures instance
        |
        v
Application starts
        |
        v
Target Group performs health checks
        |
        v
Replacement becomes healthy
        |
        v
ALB resumes load balancing across two instances
```

---

# High Availability Result

The application remained reachable throughout the failure and recovery process.

This demonstrated:

```text
Load balancing              ✅
Application health checks   ✅
Desired capacity            ✅
Automatic replacement       ✅
Graceful degradation        ✅
Self-healing                ✅
Traffic restoration         ✅
```

---

# Why This Architecture Is Highly Available

High availability is not simply:

```text
"run two servers"
```

The architecture must also be able to respond automatically to failure.

This system provides:

```text
Multiple backend instances
        +
Load balancing
        +
Health checks
        +
Automatic failure detection
        +
Automatic replacement
        =
Highly available web tier
```

---

# Application Load Balancer Role

The ALB provides a stable entry point for clients.

Instead of connecting directly to instances:

```text
Client → EC2
```

clients connect to:

```text
Client
   |
   v
ALB
   |
   v
Healthy backend instance
```

The client does not need to know:

```text
which EC2 instance exists
which EC2 instance failed
which replacement instance was created
```

The ALB hides these infrastructure changes.

---

# Target Group Role

The Target Group connects the ALB to the application instances.

It performs application health checks.

Current application health endpoint:

```text
Protocol: HTTP
Port:     8080
Path:     /
```

Only healthy targets should receive application traffic.

---

# Auto Scaling Group Role

The Auto Scaling Group manages the desired number of EC2 instances.

Configuration:

```text
Minimum: 2
Desired: 2
Maximum: 4
```

If an instance disappears:

```text
actual capacity < desired capacity
```

the ASG launches a replacement.

---

# Launch Template Role

The Launch Template defines how replacement EC2 instances are created.

It includes configuration such as:

```text
AMI
Instance type
Security Group
User Data
Tags
```

This allows new instances to be created consistently.

---

# Self-Healing Infrastructure

This architecture demonstrates self-healing infrastructure.

Instead of requiring:

```text
administrator notices outage
        |
        v
administrator logs into AWS
        |
        v
administrator launches server
        |
        v
administrator configures application
```

the system performs:

```text
instance fails
      |
      v
failure detected
      |
      v
replacement launched
      |
      v
application configured
      |
      v
health checked
      |
      v
traffic restored
```

automatically.

---

# Graceful Degradation

During replacement, the system temporarily operated with only one healthy instance.

```text
Normal state:

ALB
├── EC2 A
└── EC2 B


Failure:

ALB
└── EC2 B


Recovery:

ALB
├── EC2 B
└── EC2 C
```

This is known as graceful degradation.

The service continues functioning with reduced redundancy until capacity is restored.

---

# Important Operational Consideration

During the test, the surviving instance handled all requests.

This means production systems must ensure individual instances can temporarily handle increased traffic during recovery.

For example:

```text
Normal:

50% traffic → EC2 A
50% traffic → EC2 B


Failure:

100% traffic → EC2 B
```

This is one reason capacity planning and Auto Scaling are important.

---

# Monitoring and Investigation

High availability should also include observability.

A production design can extend this architecture using:

```text
CloudWatch Logs
EventBridge
SNS
Auto Scaling lifecycle hooks
```

Example:

```text
Instance failure
      |
      +------> ASG replacement
      |
      +------> EventBridge
                    |
                    v
                   SNS
                    |
                    v
             Operations alert
```

Logs should be stored outside the instance so that diagnostic information survives termination.

---

# Recommended Production Architecture

```text
                          Internet
                             |
                             v
                    Application Load Balancer
                             |
                             v
                        Target Group
                             |
               ---------------------------
               |                         |
               v                         v
             EC2                       EC2
        Private Subnet A          Private Subnet B
               |                         |
               ---------------------------
                             |
                             v
                    Auto Scaling Group
                             |
                             v
                     Launch Template


EC2 instances
      |
      v
CloudWatch Logs


ASG Events
      |
      v
EventBridge
      |
      v
SNS
      |
      v
Operations Notifications
```

---

# Week 5 Integration

This mini-project combined everything covered during Week 5.

## Day 1 — Application Load Balancer

Learned:

```text
ALB
Listeners
Target Groups
Health Checks
Multi-target traffic
```

---

## Day 2 — Auto Scaling

Learned:

```text
Launch Templates
Auto Scaling Groups
Min / Desired / Max capacity
Manual scaling
Target tracking concepts
```

---

## Day 3 — EBS

Learned:

```text
Block storage
Attach and mount workflow
ext4 filesystem
Persistent data
Volume expansion
Filesystem resizing
```

---

## Day 4 — EFS

Learned:

```text
Shared filesystem storage
Multiple clients
NFS concepts
Mount targets
Security Group port 2049
```

---

## Day 5 — AMIs and Launch Templates

Learned:

```text
Bootstrap vs baked images
AMI creation
Launch Template versions
Latest vs Default version
Version promotion
Rollback
Immutable infrastructure
```

---

## Day 6 — High Availability

Learned:

```text
Failure detection
Desired-state reconciliation
Automatic instance replacement
Target health
Self-healing infrastructure
Monitoring concepts
```

---

## Day 7 — Mini-Project

Validated the complete architecture:

```text
ALB
  +
Target Group
  +
Launch Template
  +
Auto Scaling Group
  +
Health Checks
  +
Failure Recovery
  =
Highly available web tier
```

---

# Commands Practiced

```bash
aws elbv2 describe-load-balancers
aws elbv2 describe-listeners
aws elbv2 describe-target-groups
aws elbv2 describe-target-health

aws autoscaling describe-auto-scaling-groups
aws autoscaling describe-scaling-activities

aws ec2 describe-instances
aws ec2 terminate-instances
aws ec2 describe-security-groups

curl
grep
```

---

# Final Architecture Behavior

The final system demonstrated:

```text
Client sends request
       |
       v
Application Load Balancer
       |
       v
Healthy Target Group members
       |
       v
EC2 application instances


If EC2 fails:

EC2 failure
    |
    v
capacity drops
    |
    v
ASG launches replacement
    |
    v
replacement starts application
    |
    v
health checks pass
    |
    v
ALB begins routing traffic
```

---

# Mini-Project Result

Successfully validated:

```text
Application Load Balancer          ✅
Healthy Target Group               ✅
Two-instance baseline              ✅
Traffic distribution               ✅
Failure simulation                 ✅
Application stays available        ✅
Automatic replacement              ✅
Replacement passes health checks   ✅
Traffic restored across 2 targets  ✅
Self-healing architecture          ✅
```

---

# Week 5 Complete

Week 5 completed successfully.

The lab progressed from individual compute and storage services to a complete highly available EC2 application architecture.

The most important lesson from the week:

```text
Cloud engineering is not just about launching servers.

It is about designing systems that:
- distribute traffic,
- detect failures,
- restore capacity,
- preserve data,
- and continue operating when components fail.
```