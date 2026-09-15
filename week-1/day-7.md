# Day 7 — Week 1 Review, Practical Challenge & Mini Project

## Objective

Combine the Linux, networking, AWS, EC2, Nginx, Security Group, troubleshooting, and Git skills learned during Week 1 into one practical deployment exercise.

## Mini Project

Deploy a custom web page on a Floci-emulated EC2 instance and verify that it is reachable from outside the server.

## Pre-Deployment Checks

Before making changes, I verified the server health using:

```bash
systemctl is-system-running
systemctl is-active nginx
systemctl is-enabled nginx
sudo ss -tulpn | grep ':8080'
df -h /
free -h
```

The checks confirmed:

* systemd was healthy
* Nginx was active
* Nginx was enabled at boot
* TCP port 8080 was listening
* sufficient disk space was available
* sufficient memory was available

## Deployment

I backed up the existing Nginx page and replaced it with a custom Week 1 page.

The new page included:

```text
Cloud Engineering Week 1 Complete
```

and confirmed that Nginx was serving the site from the EC2 instance.

## Local Validation

Inside the EC2 instance I tested:

```bash
curl http://localhost:8080
```

The custom HTML page was returned successfully.

This proved:

```text
Nginx
   ↓
port 8080
   ↓
web root
   ↓
custom page
```

was working correctly inside the server.

## External Validation

From the Mac host I tested:

```bash
curl -I http://127.0.0.1:30000
```

The result was:

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
```

This proved the complete request path:

```text
Mac
 ↓
Floci host port 30000
 ↓
Floci forwarding container
 ↓
EC2 port 8080
 ↓
Nginx
 ↓
custom website
```

## Week 1 Troubleshooting Model

The most important troubleshooting model I learned during Week 1 was:

```text
System
 ↓
Process
 ↓
Service
 ↓
Port
 ↓
Firewall / Security Group
 ↓
Network path
 ↓
Application
```

Instead of guessing, each layer should be verified independently.

## Week 1 Skills Practiced

By the end of Week 1, I had practiced:

* Linux filesystem navigation
* file permissions
* users and groups
* processes and PIDs
* systemd
* journal logs
* IP addressing
* routing
* DNS
* ports
* SSH
* Netcat
* HTTP testing
* AWS IAM concepts
* EC2
* AMIs
* instance types
* Security Groups
* Nginx
* server troubleshooting
* Git
* GitHub
* Markdown documentation

## Key Takeaway

Week 1 showed me that cloud engineering is not just about creating cloud resources.

It also requires understanding Linux, networking, security, services, logs, troubleshooting, and documentation.

## Lab Outcome

I successfully deployed and validated a custom website through:

```text
Mac → Floci → EC2 → Nginx → Custom Web Page
```

and documented the full workflow in Git.

