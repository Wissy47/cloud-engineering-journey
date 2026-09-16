# Week 2 — Day 4: Security Groups vs Network ACLs

## Objectives

- Understand Security Groups
- Understand Network ACLs
- Compare stateful vs stateless filtering
- Understand inbound and outbound rules
- Understand NACL rule priority
- Understand allow vs deny behavior
- Understand ephemeral ports
- Practice troubleshooting layered network security

## Existing Lab Environment

VPC:

`10.0.0.0/16`

Public subnet:

`10.0.1.0/24`

Private subnet:

`10.0.2.0/24`

## Security Groups

Security Groups apply to resources such as EC2 network interfaces.

Key characteristics:

- Resource/ENI level
- Stateful
- Support allow rules
- Do not support explicit deny rules
- Return traffic for an established allowed connection is automatically permitted

## Default Security Group

The custom VPC initially contained:

- Security Group: `sg-336ded22b94a16613`
- Name: `default`

Observed rules:

### Inbound

No inbound rules.

### Outbound

All IPv4 traffic was allowed to:

`0.0.0.0/0`

## Custom Web Security Group

Created:

- Security Group: `sg-294cf0cdbc3842acd`
- Name: `cloud-web-sg`

Inbound rules:

- TCP 80 from `0.0.0.0/0`
- TCP 22 from `0.0.0.0/0`

Outbound:

- All traffic to `0.0.0.0/0`

For a production environment, SSH should normally be restricted to trusted source IP ranges instead of `0.0.0.0/0`.

## Stateful Filtering

Security Groups are stateful.

If inbound traffic is permitted and a connection is established, return traffic is automatically recognized as part of that connection.

Example:

Client -> TCP 80 -> EC2

The response from EC2 back to the client is automatically permitted as return traffic.

## Network ACLs

Network ACLs apply at the subnet boundary.

Key characteristics:

- Subnet level
- Stateless
- Support both allow and deny rules
- Rules have numbers
- Rules are evaluated starting from the lowest number
- The first matching rule wins

## Default Network ACL

Network ACL:

`acl-44c70e1d7c9e2d08e`

Associated with:

- `subnet-b7a9f11b`
- `subnet-ea5a5e5d`

Default rules:

### Inbound

- Rule 100: ALLOW all
- Rule 32767: DENY all

### Outbound

- Rule 100: ALLOW all
- Rule 32767: DENY all

Because rule 100 matches first, traffic is allowed before the default deny rule is evaluated.

## NACL Rule Priority Lab

A temporary inbound deny rule was created:

- Rule number: `50`
- Protocol: TCP
- Port: `22`
- Source: `0.0.0.0/0`
- Action: DENY

This rule was evaluated before rule 100.

Result:

SSH traffic matched rule 50 first and was denied even though the Security Group allowed TCP 22.

This demonstrated that:

Security Group allow
does not guarantee
traffic will reach the instance.

The NACL must also permit the traffic.

The temporary deny rule was then removed.

## Protocol Numbers

Some common IP protocol numbers:

- `1` = ICMP
- `6` = TCP
- `17` = UDP
- `-1` = all protocols

The temporary SSH NACL rule used:

`--protocol 6`

because TCP uses IP protocol number 6.

## Stateful vs Stateless

### Security Group

Stateful.

Allowed connection return traffic is automatically recognized.

### Network ACL

Stateless.

Inbound and outbound traffic are evaluated independently.

## Ephemeral Ports

Clients normally use temporary high-numbered source ports when creating connections.

Example:

Client:

`203.0.113.10:49152`

Server:

`10.0.1.20:80`

Request:

`203.0.113.10:49152 -> 10.0.1.20:80`

Response:

`10.0.1.20:80 -> 203.0.113.10:49152`

With a stateless NACL, return traffic may require outbound rules permitting the relevant ephemeral port range.

## Security Group vs NACL

| Feature | Security Group | Network ACL |
|---|---|---|
| Scope | Resource / ENI | Subnet |
| Stateful | Yes | No |
| Allow rules | Yes | Yes |
| Deny rules | No | Yes |
| Rule priority | No numbered priority | Lowest rule number first |
| Return traffic | Automatically tracked | Evaluated separately |

## Traffic Path

Internet
↓
Network ACL
↓
Subnet
↓
Security Group
↓
EC2

Both security layers must permit traffic.

## Troubleshooting Model

When traffic cannot reach an EC2 instance:

1. Verify the route table.
2. Verify the Internet Gateway or required network path.
3. Verify the Network ACL.
4. Verify the Security Group.
5. Verify the instance IP address.
6. Verify the service is listening on the expected port.
7. Verify return traffic is permitted.

## Key Lessons

- Security Groups are stateful.
- NACLs are stateless.
- Security Groups support allow rules only.
- NACLs support allow and deny rules.
- NACL rule numbers determine evaluation order.
- Lower rule numbers are evaluated first.
- A NACL can block traffic even when a Security Group allows it.
- Stateless filtering requires thinking about both traffic directions.
- Ephemeral ports matter when using restrictive NACLs.