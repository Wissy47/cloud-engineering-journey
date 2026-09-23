# Week 4 Day 3 — Security Groups and Network ACLs

## Objective

Understand the difference between Security Groups and Network ACLs in AWS, and how both affect network traffic.

## VPC

* VPC ID: `vpc-c1d0eaf8`
* VPC CIDR: `10.40.0.0/16`

## Public Subnet

* Subnet ID: `subnet-f8d5a80c`
* CIDR: `10.40.1.0/24`

## Private Subnet

* Subnet ID: `subnet-9a4a8120`
* CIDR: `10.40.2.0/24`

## Security Group

Created and inspected:

* Security Group: `week4-web-sg`
* Security Group ID: `sg-22fad3cc5698529e6`

### Inbound Rule

```text
TCP 80
Source: 0.0.0.0/0
```

This allows HTTP traffic from any IPv4 address.

### Outbound Rule

```text
All traffic
Destination: 0.0.0.0/0
```

## Security Group Concepts

* Security Groups operate at the ENI/resource level.
* Security Groups are stateful.
* If inbound traffic is allowed, response traffic is automatically allowed.
* Security Groups support allow rules only.
* Traffic that does not match an allow rule is implicitly denied.

## Default Network ACL

Default NACL:

```text
acl-1ff2ffb26b9b550b0
```

Initially, both subnets were associated with this NACL.

### Default NACL Rules

Inbound:

```text
100    ALLOW all traffic
32767  DENY all traffic
```

Outbound:

```text
100    ALLOW all traffic
32767  DENY all traffic
```

Because rule `100` is evaluated first, traffic is allowed before the final catch-all deny rule is reached.

## Custom Public NACL

Created:

```text
acl-4df6f0c6e5ee0d486
```

The custom NACL initially contained only the default deny rules.

### Initial Custom NACL State

Inbound:

```text
32767 DENY all traffic
```

Outbound:

```text
32767 DENY all traffic
```

## Custom NACL Rules Added

### Inbound

```text
Rule 100
ALLOW TCP 80
Source: 0.0.0.0/0
```

### Outbound

```text
Rule 100
ALLOW TCP 1024-65535
Destination: 0.0.0.0/0
```

The outbound ephemeral port range allows response traffic for inbound client connections.

## NACL Association

The public subnet was originally associated with the default NACL:

```text
Association ID:
aclassoc-4b738e5a18d7d7eb9

NACL:
acl-1ff2ffb26b9b550b0
```

The association was replaced with the custom NACL.

New association:

```text
NACL:
acl-4df6f0c6e5ee0d486

Association ID:
aclassoc-697ad7a71948a2180

Subnet:
subnet-f8d5a80c
```

## Final NACL State

Public subnet:

```text
subnet-f8d5a80c
→ acl-4df6f0c6e5ee0d486
→ Custom NACL
```

Private subnet:

```text
subnet-9a4a8120
→ acl-1ff2ffb26b9b550b0
→ Default NACL
```

## Security Group vs NACL

| Feature             | Security Group | Network ACL |
| ------------------- | -------------- | ----------- |
| Applied to          | ENI/resource   | Subnet      |
| Stateful            | Yes            | No          |
| Allow rules         | Yes            | Yes         |
| Explicit deny rules | No             | Yes         |
| Rule order matters  | No             | Yes         |

## Traffic Flow

```text
Internet
   ↓
Route Table
   ↓
Network ACL
   ↓
Security Group
   ↓
EC2 / Application
```

## Key Lessons

* Route tables decide where traffic goes.
* Network ACLs control traffic at the subnet level.
* Security Groups control traffic at the resource/ENI level.
* Security Groups are stateful.
* Network ACLs are stateless.
* NACLs require inbound and outbound rules for return traffic.
* NACLs support explicit deny rules.
* Security Groups do not support explicit deny rules.
* A Security Group and NACL must both permit the traffic for a connection to succeed.
* A custom NACL must be associated with a subnet before its rules affect that subnet.

## Troubleshooting Order

When a network connection fails, check:

1. IP configuration
2. Route table
3. Internet Gateway or NAT path
4. Network ACL
5. Security Group
6. Application listener
7. Operating system firewall

