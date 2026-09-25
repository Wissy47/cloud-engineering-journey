# Week 5 Day 1 — Application Load Balancer, Target Groups, Health Checks, and Multi-AZ Backends

## Objective

Build and troubleshoot a multi-AZ Application Load Balancer architecture using:

* Application Load Balancer
* Listener
* Target Group
* Health Checks
* Dedicated ALB Security Group
* Dedicated Backend Security Group
* Two EC2 backend instances
* Private subnets across two Availability Zones
* Load balancing between healthy backend instances

The goal was to understand how a single public load balancer can distribute requests across multiple private backend servers.

---

## Existing Week 4 Network

VPC:

```text
vpc-c1d0eaf8
10.40.0.0/16
```

Public subnets:

```text
subnet-f8d5a80c
10.40.1.0/24
us-east-1a
```

```text
subnet-fc160cb6
10.40.3.0/24
us-east-1b
```

Private subnets:

```text
subnet-9a4a8120
10.40.2.0/24
us-east-1a
```

```text
subnet-9fb59c20
10.40.4.0/24
us-east-1b
```

---

## Architecture

The final lab architecture was:

```text
                     Client
                       |
                       v
             Application Load Balancer
                    HTTP :80
                 /            \
                /              \
               v                v
      Web Server A          Web Server B
       HTTP :8080            HTTP :8080
       us-east-1a            us-east-1b
       Private subnet        Private subnet
```

The backend instances were not exposed directly to users.

Users connected to the Application Load Balancer, which forwarded requests to healthy targets.

---

## Application Load Balancer

Load Balancer:

```text
Name: week5-web-alb
Type: application
Scheme: internet-facing
State: active
```

Load Balancer ARN:

```text
arn:aws:elasticloadbalancing:us-east-1:000000000000:loadbalancer/app/week5-web-alb/7c355d47fdd94ac2
```

DNS name:

```text
week5-web-alb-7c355d47fdd94ac2.elb.localhost.floci.io
```

The ALB spans two public subnets:

```text
us-east-1a
subnet-f8d5a80c
```

```text
us-east-1b
subnet-fc160cb6
```

This provides a multi-AZ entry point for client traffic.

---

## ALB Security Group

ALB Security Group:

```text
sg-f92cb6acdca55dbed
```

The ALB Security Group allows:

```text
Inbound:
TCP 80 from 0.0.0.0/0
```

This allows clients to send HTTP requests to the load balancer.

---

## Target Group

Target Group:

```text
week5-web-targets
```

Target Group ARN:

```text
arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/week5-web-targets/f21047cfbd204e7c
```

Configuration:

```text
Protocol: HTTP
Default Port: 80
Target Type: instance
Health Check Protocol: HTTP
Health Check Path: /
Expected HTTP Code: 200
```

Health check settings included:

```text
HealthCheckIntervalSeconds: 30
HealthCheckTimeoutSeconds: 5
HealthyThresholdCount: 5
UnhealthyThresholdCount: 2
```

---

## Listener

The ALB listener was configured as:

```text
Protocol: HTTP
Port: 80
```

The listener forwards requests to:

```text
week5-web-targets
```

Traffic flow:

```text
Client
   |
   v
ALB :80
   |
   v
Listener
   |
   v
Target Group
```

---

## Backend Security Group

Backend Security Group:

```text
sg-e57859fda5ead5e67
week5-backend-sg
```

Instead of allowing the internet to connect directly to the EC2 instances, the backend Security Group allows traffic from the ALB Security Group.

Initial configuration:

```text
Inbound:
TCP 80 from sg-f92cb6acdca55dbed
```

After discovering the Floci port conflict, TCP `8080` was also allowed from the ALB Security Group.

Final concept:

```text
Internet
   |
   v
ALB Security Group
   |
   | HTTP
   v
Backend Security Group
   |
   v
EC2 backend
```

This is better than exposing backend EC2 instances directly to:

```text
0.0.0.0/0
```

---

## Backend AMI

The backend instances used the AMI created during Week 3:

```text
AMI ID:
ami-19e6ea348547095a9

Name:
week3-day4-cloud-lab-ami

Architecture:
arm64
```

The ARM architecture matched the use of:

```text
t4g.micro
```

---

## Backend EC2 Instances

Two backend servers were launched across two Availability Zones.

### Web Server A

```text
Instance ID:
i-1a418b15867c24524

Availability Zone:
us-east-1a

Private Subnet:
subnet-9a4a8120
```

### Web Server B

```text
Instance ID:
i-edb6dcbc6338e090b

Availability Zone:
us-east-1b

Private Subnet:
subnet-9fb59c20
```

Both instances were placed in private subnets.

They did not need public IP addresses because client traffic reached them through the Application Load Balancer.

---

## User Data

User Data was used to create a simple test web application.

The application generated different output on each server so load balancing could be observed.

Web Server A returned:

```html
<h1>Week 5 Load Balancer Lab</h1>
<h2>Web Server A</h2>
<p>Availability Zone: us-east-1a</p>
```

Web Server B returned:

```html
<h1>Week 5 Load Balancer Lab</h1>
<h2>Web Server B</h2>
<p>Availability Zone: us-east-1b</p>
```

---

## Initial Health Check Failure

After registering the first pair of backend instances, the target health showed:

```text
State: unhealthy
Reason: Target.FailedHealthChecks
```

Both instances failed their health checks.

Instead of changing infrastructure randomly, the problem was diagnosed layer by layer.

---

## Troubleshooting Process

The following layers were checked:

1. Application Load Balancer state
2. Listener configuration
3. Target Group configuration
4. Target Group health check path
5. Backend Security Group
6. Security Group attachment on EC2
7. User Data
8. Application listener
9. Floci networking behavior

The ALB, listener, target group, and Security Groups were all configured correctly.

The problem was eventually traced to the application layer.

---

## User Data Troubleshooting

The original User Data did not appear as:

```text
/var/lib/user-data.sh
```

inside the Floci EC2 container.

The metadata endpoint was inspected directly:

```bash
curl http://169.254.169.254/latest/user-data
```

The returned data was Base64 encoded.

It was decoded manually for troubleshooting:

```bash
curl -s http://169.254.169.254/latest/user-data \
  | base64 -d \
  > /tmp/week5-user-data.sh
```

The script was then inspected:

```bash
cat /tmp/week5-user-data.sh
```

and executed with debug tracing:

```bash
bash -x /tmp/week5-user-data.sh
```

---

## Application Failure

The Python HTTP server failed to start.

The application log showed:

```text
OSError: [Errno 98] Address already in use
```

Port inspection showed:

```text
169.254.169.254:80
```

was already occupied by Floci's metadata implementation.

Therefore:

```text
python3 -m http.server 80 --bind 0.0.0.0
```

could not bind to port `80`.

---

## Floci Workaround

The backend application was moved from:

```text
Port 80
```

to:

```text
Port 8080
```

The ALB continued listening publicly on port `80`.

The new architecture became:

```text
Client
   |
   | HTTP :80
   v
Application Load Balancer
   |
   | HTTP :8080
   v
Backend EC2
```

This was a local Floci workaround.

In real AWS, a web server can normally listen directly on port `80` without conflicting with the EC2 Instance Metadata Service.

---

## Backend Validation

The application was tested inside each EC2 container.

Example:

```bash
curl http://127.0.0.1:8080
```

The servers successfully returned their HTML pages.

Port inspection also confirmed the application was listening on:

```text
0.0.0.0:8080
```

---

## Target Registration

The new backend instances were registered with port override `8080`.

This was necessary because the target group originally used port `80`.

The registered targets became:

```text
i-1a418b15867c24524:8080
i-edb6dcbc6338e090b:8080
```

The target group's health check used:

```text
HealthCheckPort: traffic-port
```

so each instance was health checked on its registered port.

---

## Healthy Targets

After the backend application was moved to port `8080`, both targets became healthy.

```text
i-1a418b15867c24524 :8080 → healthy
i-edb6dcbc6338e090b :8080 → healthy
```

This confirmed:

```text
ALB
   |
   v
Target Group
   |
   v
Private EC2 backends
```

was functioning correctly.

---

## Floci ALB Listener Troubleshooting

Even though both targets were healthy, the ALB DNS name initially could not be reached from the Mac host.

The main Floci container only exposed:

```text
4566:4566
```

The ALB listener used port:

```text
80
```

but Docker had not published that port to the host.

The existing Floci container was also discovered to be running on Docker's default:

```text
bridge
```

network rather than being managed by the current Docker Compose project.

---

## Docker Port Forwarding Workaround

A small forwarding container was used to expose host port `80` to Floci's internal ALB listener.

This provided:

```text
Mac :80
   |
   v
Docker forwarding container
   |
   v
Floci ALB listener :80
```

After this, the ALB DNS name became reachable from the host.

---

## Load Balancer Test

The load balancer was tested using:

```bash
curl http://week5-web-alb-7c355d47fdd94ac2.elb.localhost.floci.io
```

The first response showed:

```text
Web Server A
Availability Zone: us-east-1a
```

Multiple requests were then sent:

```bash
for i in {1..6}; do
  curl -s http://week5-web-alb-7c355d47fdd94ac2.elb.localhost.floci.io
  echo
done
```

The responses alternated between:

```text
Web Server A
us-east-1a
```

and:

```text
Web Server B
us-east-1b
```

This confirmed that the Application Load Balancer was distributing requests across both healthy backend instances.

---

## Final Traffic Flow

```text
                         Client
                            |
                            | HTTP :80
                            v
                 Application Load Balancer
                            |
                       Listener :80
                            |
                            v
                       Target Group
                      /            \
                     /              \
                    v                v
           Web Server A          Web Server B
               :8080                :8080
            us-east-1a           us-east-1b
         Private Subnet       Private Subnet
```

---

## Key Concepts Learned

* An Application Load Balancer provides one entry point for multiple backend servers.
* An ALB can span multiple Availability Zones.
* Listeners define which ports and protocols the ALB accepts.
* Target Groups define where traffic is forwarded.
* Health checks prevent unhealthy targets from receiving normal traffic.
* Backend instances do not need public IP addresses when accessed through an ALB.
* Backend Security Groups can trust the ALB Security Group instead of the entire internet.
* Target ports do not have to match listener ports.
* An ALB can listen on port `80` while forwarding traffic to backend port `8080`.
* Health check failures should be diagnosed systematically.
* A healthy ALB configuration does not guarantee the backend application is actually running.
* Application logs and listening ports are essential troubleshooting tools.
* Multi-AZ backends improve availability.
* Emulator-specific behavior should be distinguished from real AWS behavior.

---

## Troubleshooting Workflow

When ALB targets are unhealthy:

1. Confirm the ALB is active.
2. Confirm the listener exists.
3. Confirm the listener forwards to the correct target group.
4. Confirm targets are registered.
5. Check target health state and reason.
6. Verify the backend Security Group.
7. Verify the correct Security Group is attached.
8. Check NACLs.
9. Verify the application is listening on the target port.
10. Test the application locally.
11. Inspect application logs.
12. Verify the health check protocol, path, port, and expected HTTP response.

Useful commands:

```bash
aws elbv2 describe-load-balancers
aws elbv2 describe-listeners
aws elbv2 describe-target-groups
aws elbv2 describe-target-health
aws ec2 describe-security-groups
aws ec2 describe-instances
docker exec <container> ss -tulpn
docker exec <container> curl http://127.0.0.1:8080
docker exec <container> cat /var/log/week5-web.log
```

---

## Lab Result

Successfully built and troubleshot a multi-AZ Application Load Balancer architecture.

The final setup distributed HTTP requests between two healthy private EC2 backend instances running in separate Availability Zones.

Observed result:

```text
Request 1 → Web Server B
Request 2 → Web Server A
Request 3 → Web Server B
Request 4 → Web Server A
Request 5 → Web Server B
Request 6 → Web Server A
```

