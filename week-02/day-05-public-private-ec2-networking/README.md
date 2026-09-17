# Week 2 — Day 5: Public EC2 + Private EC2 Networking

## Objectives

- Launch EC2 instances into public and private subnets
- Understand private communication inside a VPC
- Test public-to-private connectivity
- Test private-to-public connectivity
- Understand the difference between subnet visibility and private reachability
- Connect Security Group design with VPC routing

## Existing Network

VPC:

`10.0.0.0/16`

Public subnet:

`10.0.1.0/24`

Private subnet:

`10.0.2.0/24`

Public Security Group:

`cloud-web-sg`

Private Security Group:

`cloud-private-sg`

## EC2 Images

Floci exposed several AMIs, including:

- Amazon Linux 2
- Amazon Linux 2023
- Ubuntu 20.04
- Ubuntu 22.04
- Ubuntu 24.04 ARM64
- Ubuntu 24.04 AMD64
- Debian 12
- Alpine
- Windows Server 2022

For the Apple Silicon lab environment, Ubuntu 24.04 ARM64 was used:

`ami-ubuntu2404-arm64`

Instance type:

`t4g.micro`

## Private Security Group

A dedicated Security Group was created for the private EC2 instance:

`cloud-private-sg`

It allowed:

- ICMP from `10.0.1.0/24`
- TCP 8080 from `10.0.1.0/24`

The goal was to allow controlled communication from the public subnet to the private instance.

## EC2 Instances

### Public EC2

Instance ID:

`i-59f24c4f29bf400be`

Subnet:

`subnet-b7a9f11b`

Security Group:

`cloud-web-sg`

Floci container:

`12e07e36ff50`

Container/private IP:

`172.17.0.7`

### Private EC2

Instance ID:

`i-b3c6e729388c12973`

Subnet:

`subnet-ea5a5e5d`

Security Group:

`cloud-private-sg`

Floci container:

`4473c39f17db`

Container/private IP:

`172.17.0.8`

## Floci Networking Observation

Although the AWS-style subnets were:

- `10.0.1.0/24`
- `10.0.2.0/24`

the Docker-backed EC2 containers were assigned addresses in:

`172.17.0.0/16`

This is a local emulator implementation detail.

In real AWS, EC2 instances would normally receive private addresses from their subnet CIDR ranges.

## Public-to-Private Test

A Python HTTP server was started on the private EC2:

```bash
python3 -m http.server 8080 --bind 0.0.0.0

From the public EC2, connectivity was tested with:

curl http://172.17.0.8:8080

The request succeeded and returned an HTTP directory listing.

This demonstrated:

Public EC2 -> Private EC2 communication works over private networking.

Private-to-Public Test

A Python HTTP server was started on the public EC2.

From the private EC2:

curl http://172.17.0.7:8080

The request also succeeded.

This demonstrated bidirectional private connectivity.

Linux Routing Observed

On the private EC2 container:

default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0

This represents the underlying Docker/Floci networking.

At the AWS design level, the private subnet still uses the VPC-local route and does not have a direct route to the Internet Gateway.

Key Networking Lesson

A private instance does not need a public IP to communicate with another instance inside the same VPC.

Public/private subnet classification determines internet routing, not whether resources can communicate privately.

Architecture
Internet
   |
   v
Public EC2
   |
   | private VPC communication
   v
Private EC2
Important Distinction

Public subnet:

Has a route to an Internet Gateway

Private subnet:

Does not have a direct route to an Internet Gateway

Both:

Can still communicate privately inside the VPC if routing and security rules allow it
Troubleshooting Lesson

A previous test returned:

Connection refused

This meant the destination was reachable, but no process was listening on TCP port 8080.

After starting the HTTP server, the connection succeeded.

Useful distinction:

Connection refused = host reachable, service/port not accepting connections
Connection timed out = traffic may be blocked, misrouted, or destination unreachable
Key Concepts Learned
EC2 instances can communicate privately across subnets in the same VPC.
Private instances do not need public IPs for internal communication.
Public/private subnet classification relates to routing.
Security Groups should be scoped according to intended traffic.
Internal service reachability still depends on an application listening on the target port.
Floci uses Docker-backed networking, so local IP behavior differs from real AWS.