# Week 2 — Day 7: AWS VPC Mini Project

## Objective

Build, validate, and explain a complete AWS-style VPC architecture using:

- Custom VPC
- Public subnet
- Private subnet
- Route tables
- Internet Gateway
- NAT Gateway
- Elastic IP
- Security Groups
- Network ACLs
- Public EC2
- Private EC2
- Private VPC communication

The lab was completed using Floci as a local AWS-compatible environment.

---

## Final Architecture

VPC:

`10.0.0.0/16`

### Public Subnet

CIDR:

`10.0.1.0/24`

Subnet ID:

`subnet-b7a9f11b`

Availability Zone:

`us-east-1a`

Route table:

`rtb-b515d0c4`

Routes:

- `10.0.0.0/16 -> local`
- `0.0.0.0/0 -> igw-82949a9e`

Resources:

- Public EC2
- NAT Gateway

### Private Subnet

CIDR:

`10.0.2.0/24`

Subnet ID:

`subnet-ea5a5e5d`

Availability Zone:

`us-east-1a`

Main/private route table:

`rtb-aa530eaf0ac1b2768`

Routes:

- `10.0.0.0/16 -> local`
- `0.0.0.0/0 -> nat-226e6e0aee6a79548`

Resources:

- Private EC2

---

## Internet Gateway

Internet Gateway:

`igw-82949a9e`

Attached to:

`vpc-9d40ccf5`

The Internet Gateway provides the public subnet with a path to the internet.

---

## NAT Gateway

NAT Gateway:

`nat-226e6e0aee6a79548`

State:

`available`

Connectivity type:

`public`

Subnet:

`subnet-b7a9f11b`

Elastic IP allocation:

`eipalloc-e29556f106deebf5b`

The NAT Gateway allows resources in the private subnet to initiate outbound internet connections without giving those resources a direct internet route.

---

## Public EC2

Instance ID:

`i-59f24c4f29bf400be`

Subnet:

`subnet-b7a9f11b`

Security Group:

`cloud-web-sg`

Floci container IP:

`172.17.0.7`

The public Security Group allowed:

- TCP 80
- TCP 22

from:

`0.0.0.0/0`

For a production environment, SSH should normally be restricted to trusted source IP ranges.

---

## Private EC2

Instance ID:

`i-b3c6e729388c12973`

Subnet:

`subnet-ea5a5e5d`

Security Group:

`cloud-private-sg`

Floci container IP:

`172.17.0.8`

The private Security Group allowed controlled traffic from the public subnet.

---

## Private Communication Test

A temporary HTTP server was started on the private EC2:

```bash
python3 -m http.server 8080 --bind 0.0.0.0

From the public EC2:

curl http://172.17.0.8:8080

The request succeeded.

A server was then started on the public EC2 and tested from the private EC2:

curl http://172.17.0.7:8080

This also succeeded.

This demonstrated bidirectional private communication.

Route Table Validation
Public Route Table
10.0.0.0/16 -> local
0.0.0.0/0   -> Internet Gateway

This makes the public subnet public by routing.

Private Route Table
10.0.0.0/16 -> local
0.0.0.0/0   -> NAT Gateway

This keeps the private subnet private while still allowing outbound internet access.

Traffic Flows
Public EC2 to Internet
Public EC2
↓
Public Route Table
↓
Internet Gateway
↓
Internet
Private EC2 to Internet
Private EC2
↓
Private Route Table
↓
NAT Gateway
↓
Public Subnet
↓
Internet Gateway
↓
Internet
Public EC2 to Private EC2
Public EC2
↓
10.0.0.0/16 local route
↓
Private EC2
Private EC2 to Public EC2
Private EC2
↓
10.0.0.0/16 local route
↓
Public EC2
Failure Scenarios
NAT Gateway Deleted

If the private route table still points to a deleted NAT Gateway:

Private resources lose outbound internet connectivity.
Internal VPC communication can continue through the local route.
Public IGW Route Removed

If:

0.0.0.0/0 -> Internet Gateway

is removed from the public route table:

Public subnet internet access stops.
NAT Gateway internet access stops.
Private subnet outbound internet access also stops.
Local VPC Route

The route:

10.0.0.0/16 -> local

allows resources inside the VPC to communicate privately across subnets.

Security Model

Traffic can be controlled at multiple layers:

Internet
↓
Route Table
↓
Network ACL
↓
Subnet
↓
Security Group
↓
EC2
↓
Application

Security Groups are stateful.

Network ACLs are stateless.

Security Groups support allow rules only.

Network ACLs support both allow and deny rules.

Important Concepts Reinforced
VPCs are regional.
Subnets belong to one Availability Zone.
Subnet CIDRs cannot overlap.
Public/private subnet classification is based on routing.
A public IP does not make a subnet public.
Public subnets route directly to an Internet Gateway.
Private subnets can route outbound internet traffic through a NAT Gateway.
NAT Gateways belong in public subnets.
Explicit route-table associations override main route-table inheritance.
AWS uses longest-prefix matching.
Security Groups are stateful.
Network ACLs are stateless.
Resources in different subnets of the same VPC can communicate privately.
Floci Lab Note

The AWS control-plane configuration was modeled using Floci.

Floci used Docker-backed EC2 containers with addresses such as:

172.17.0.7
172.17.0.8

In real AWS, the EC2 instances would normally receive private IP addresses from the configured subnet CIDR ranges such as:

10.0.1.x
10.0.2.x

The Docker networking behavior should therefore be treated as a local emulator implementation detail.

Conclusion

This mini project combined the main AWS VPC networking concepts into one working architecture.

The final environment included:

Custom VPC
Public subnet
Private subnet
Internet Gateway
NAT Gateway
Elastic IP
Public and private route tables
Security Groups
Network ACLs
Public EC2
Private EC2
Private inter-instance connectivity
Private outbound internet architecture