# Week 5 Day 6 — Highly Available EC2 Architecture and Failure Recovery

## Objective

Combine the Week 5 components into a highly available EC2 architecture and verify that the system can recover automatically when an instance fails.

The lab combined:

* Application Load Balancer
* Target Group
* Auto Scaling Group
* Launch Template
* Health Checks
* Private EC2 instances
* Desired capacity
* Automatic instance replacement
* Failure recovery
* Load balancing after recovery
* Monitoring concepts for failed instances

---

# Architecture

The target architecture was:

```text
                         Internet
                            |
                            v
                  Application Load Balancer
                            |
                            v
                       Target Group
                         :8080
                       /       \
                      /         \
                     v           v
                  EC2 A        EC2 B
                     \           /
                      \         /
                    Auto Scaling Group
                    Min=2 Max=4
                           |
                           v
                    Launch Template
```

The goal was to ensure that no individual EC2 instance was critical to the application.

---

# Auto Scaling Baseline

The Auto Scaling Group configuration was inspected:

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

Existing instances:

```text
i-ba7ea7b81f5c9b519
i-1093c1b54e1afea7b
```

Both were:

```text
InService
Healthy
```

---

# Load Balancer Baseline

The Application Load Balancer was tested repeatedly.

Requests alternated between:

```text
i-ba7ea7b81f5c9b519
```

and:

```text
i-1093c1b54e1afea7b
```

This proved that both backend instances were actively receiving traffic.

Traffic flow:

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

# Bash Array Observation

The ASG instance IDs were stored in an array:

```bash
ASG_INSTANCE_IDS=($(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names week5-web-asg \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text))
```

The current shell behaved with 1-based array indexing.

Therefore:

```bash
echo "${ASG_INSTANCE_IDS[1]}"
```

returned the first element.

This was consistent with zsh behavior.

---

# Simulating Instance Failure

The first ASG-managed instance was selected:

```text
i-ba7ea7b81f5c9b519
```

It was terminated manually:

```bash
aws ec2 terminate-instances \
  --instance-ids "$FAILED_INSTANCE"
```

The instance transitioned from:

```text
running
```

to:

```text
shutting-down
```

Importantly, the Auto Scaling Group's desired capacity remained:

```text
2
```

This simulated unexpected capacity loss rather than intentional scale-in.

---

# Auto Scaling Recovery

After termination, the ASG was inspected.

Result:

```text
i-1093c1b54e1afea7b   InService   Healthy
i-e0963642ea8f2bb81   Pending     Healthy
```

The new instance:

```text
i-e0963642ea8f2bb81
```

was automatically launched.

This demonstrated:

```text
Desired capacity = 2
        |
        v
One instance disappears
        |
        v
Actual capacity = 1
        |
        v
ASG detects capacity deficit
        |
        v
ASG launches replacement
```

---

# Scaling Activity History

Scaling activities were inspected using:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name week5-web-asg \
  --max-items 10 \
  --output table
```

Floci reported:

```text
Persisted Auto Scaling state referenced instance containers
that are no longer running.
```

It then removed:

```text
i-ba7ea7b81f5c9b519
```

from its active state and launched:

```text
i-e0963642ea8f2bb81
```

The replacement launch completed successfully.

---

# Replacement Instance Becomes Healthy

The ASG was checked again.

Final state:

```text
i-1093c1b54e1afea7b   InService   Healthy
i-e0963642ea8f2bb81   InService   Healthy
```

The target group was also checked:

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

The replacement instance had successfully:

```text
launched
bootstrapped
started the application
registered with the target group
passed health checks
```

---

# Application Availability After Failure

The ALB was tested again:

```bash
for i in {1..6}; do
  curl -s "$ALB_URL"
  echo
done
```

Traffic alternated between:

```text
i-1093c1b54e1afea7b
```

and:

```text
i-e0963642ea8f2bb81
```

This confirmed the replacement instance was actively serving application traffic.

---

# Self-Healing Architecture

The full recovery sequence was:

```text
Healthy application
      |
      v
One EC2 instance fails
      |
      v
ASG detects missing capacity
      |
      v
Replacement EC2 is launched
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
ALB sends traffic to replacement
```

This demonstrated the self-healing nature of the architecture.

---

# High Availability vs Multiple Servers

Having multiple EC2 instances alone does not automatically create high availability.

A resilient architecture also requires:

```text
failure detection
health checks
automatic replacement
load balancing
desired capacity management
shared/external persistent state
```

The system must be able to recover without depending on manual intervention.

---

# ASG Health vs Application Health

The architecture contained multiple layers of health monitoring.

### Auto Scaling Health

The ASG evaluates whether the EC2 instance should remain part of the group.

### Target Group Health

The ALB checks whether the application responds correctly on:

```text
HTTP :8080
/
```

Therefore:

```text
EC2 health
    ≠
application health
```

An instance can exist while the application itself is unavailable.

---

# Monitoring Failed Instances

An important operational question was explored:

```text
How do we know when an instance fails,
and how do we investigate it after Auto Scaling replaces it?
```

In real AWS, several services can be combined.

---

## EventBridge

Auto Scaling lifecycle events can be sent to Amazon EventBridge.

Examples include:

```text
Instance launch successful
Instance launch unsuccessful
Instance termination successful
Instance termination unsuccessful
```

Conceptually:

```text
Auto Scaling event
      |
      v
EventBridge
```

---

## SNS Notifications

EventBridge or Auto Scaling can notify an SNS topic.

Architecture:

```text
ASG
 |
 v
EventBridge
 |
 v
SNS
 |
 v
Email / Operations notification
```

This can notify operators when instances are launched or terminated.

---

# Centralized Logging

A major operational rule is:

```text
Do not keep important diagnostic logs only on EC2.
```

If the instance is terminated, local logs may disappear.

Instead:

```text
EC2 A ──┐
        ├──> CloudWatch Logs
EC2 B ──┘
```

Useful logs can include:

```text
application logs
Nginx/Apache logs
system logs
startup logs
User Data logs
```

This means failure evidence remains available even after the EC2 instance has been terminated.

---

# Termination Lifecycle Hooks

For deeper investigations, an Auto Scaling lifecycle hook can pause termination.

Instead of:

```text
unhealthy
   |
   v
terminate immediately
```

the workflow can become:

```text
unhealthy
   |
   v
Terminating:Wait
   |
   +--> collect logs
   +--> capture diagnostics
   +--> notify operations
   +--> snapshot important storage
   |
   v
complete lifecycle action
   |
   v
terminate
```

This gives operations teams time to inspect or collect evidence.

---

# Recommended Production Monitoring Architecture

```text
                      ALB
                       |
                  Target Group
                       |
                Auto Scaling Group
                 /           \
               EC2           EC2
                |             |
                +------┬------+
                       |
                       v
                CloudWatch Logs


ASG lifecycle events
        |
        v
    EventBridge
        |
        v
       SNS
        |
        v
Operations notification


Instance termination
        |
        v
Lifecycle Hook
        |
        v
Collect diagnostics
        |
        v
Allow termination
```

---

# Important Operational Lesson

High availability does not mean failures never happen.

It means:

```text
failure happens
      +
system detects it
      +
application remains available
      +
capacity is restored
      +
failure evidence remains available
```

This is a key difference between simply running servers and operating resilient infrastructure.

---

# Key Concepts Learned

* Auto Scaling maintains desired capacity.
* Terminating an ASG instance does not automatically reduce desired capacity.
* The ASG replaces missing capacity.
* Replacement instances are created from the Launch Template.
* New instances must pass target-group health checks before serving traffic.
* The ALB sends traffic only to healthy targets.
* A failed EC2 instance does not need to bring down the application.
* ASG activity history is useful for troubleshooting scaling events.
* High availability requires automated recovery.
* Failed-instance logs should be centralized.
* EventBridge can detect lifecycle events.
* SNS can deliver operational notifications.
* Lifecycle hooks can delay termination for diagnostics.
* Operations and observability are part of high-availability architecture.

---

# Commands Practiced

```bash
aws autoscaling describe-auto-scaling-groups
aws autoscaling describe-scaling-activities

aws ec2 terminate-instances

aws elbv2 describe-target-health

curl
```

---

# Final Result

Successfully demonstrated:

```text
2 healthy ASG instances              ✅
ALB distributing traffic             ✅
Manual EC2 failure simulation        ✅
ASG detects lost capacity            ✅
Replacement instance launched        ✅
Replacement becomes InService        ✅
Target Group health passes           ✅
ALB serves replacement instance      ✅
Application continues operating      ✅
Failure-monitoring architecture       ✅ conceptual
```
