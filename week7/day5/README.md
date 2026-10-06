# Week 7 Day 5 — RDS Networking & Security

## Objective

Learn how Amazon RDS fits securely inside a VPC using private subnets, DB subnet groups, security groups, and private database access.

The goal was to understand how to allow an application to connect to PostgreSQL without exposing the database directly to the Internet.

---

## Core Architecture

```text
Users
  │
  ▼
Application Tier
  │
  │ TCP 5432
  ▼
RDS Security Group
  │
  ▼
Private RDS PostgreSQL
```

The database remains private, while the application tier is explicitly allowed to connect.

---

## Key Concepts

### DB Subnet Group

A DB subnet group tells RDS which subnets it is allowed to use for database placement.

Example:

```text
VPC
├── Private Subnet A
├── Private Subnet B
└── DB Subnet Group
    ├── Subnet A
    └── Subnet B
```

The subnet group should normally span at least two Availability Zones.

This does **not** mean two independent RDS databases are created.

It gives AWS multiple placement options and supports high-availability designs such as Multi-AZ.

---

## Multi-AZ

With Multi-AZ, AWS may maintain:

```text
AZ A
└── Primary RDS

AZ B
└── Standby RDS
```

The application still normally uses one RDS endpoint and the same database credentials.

AWS manages failover behind the scenes.

---

## RDS Security Group

The RDS security group determines what network traffic is allowed to reach the database.

Bad rule:

```text
TCP 5432
Source: 0.0.0.0/0
```

This exposes PostgreSQL to the entire IPv4 Internet.

Better rule:

```text
TCP 5432
Source: Application Security Group
```

This means only resources associated with the application SG are allowed to reach PostgreSQL.

---

## Why SG-to-SG Rules Are Better

If an EC2 application instance changes private IP:

```text
10.40.1.25
→
10.40.1.97
```

a fixed-IP rule could break.

Using:

```text
Source = week7-app-sg
```

avoids depending on a single instance IP.

---

## Publicly Accessible

```text
PubliclyAccessible = false
```

means the database is not intended for direct public Internet access.

An EC2 application in the same VPC can still connect privately.

---

## NAT Gateway

A NAT Gateway allows private resources to initiate outbound Internet access.

Conceptually:

```text
Private EC2
   │
   ▼
NAT Gateway
   │
   ▼
Internet
```

It does **not** provide:

```text
Internet
   │
   ▼
Private RDS
```

A NAT Gateway therefore does not make a private RDS database publicly reachable inbound.

---

## Network Authorization vs Database Authentication

### Network Authorization

Question:

```text
Can this client reach the database?
```

Controlled by:

- VPC
- subnets
- routes
- security groups
- ports
- DNS/network path

### Database Authentication

Question:

```text
Is this user allowed to log in?
```

Controlled by:

- username
- password
- database roles
- IAM DB authentication where used

A connection can fail even when one side is correct.

Examples:

```text
Network works ✅
Credentials wrong ❌
```

or:

```text
Credentials correct ✅
Network blocked ❌
```

---

## PostgreSQL Port

PostgreSQL commonly uses:

```text
TCP 5432
```

The intended security flow is:

```text
Application SG
    │
    │ TCP 5432
    ▼
RDS SG
    │
    ▼
PostgreSQL
```

---

## Troubleshooting RDS Connectivity

If RDS reports:

```text
available
```

but the application cannot connect, check the following layers:

1. RDS status
2. Endpoint
3. DNS resolution
4. Routing
5. Security group rules
6. TCP port
7. TLS
8. Database username/password
9. Target database existence

An `available` control-plane state does not guarantee successful application connectivity.

---

## floci vs Real AWS

In real AWS, a private RDS instance is not normally directly reachable from a public laptop.

In floci, the database may still be reachable through a local proxy such as:

```text
localhost:7001
```

That is emulator behavior.

It does not mean the RDS instance is conceptually public.

The AWS architecture should still be designed as:

```text
Application
    │
    ▼
Private RDS
```

with access controlled by security groups.

---

## Responsibility of Each Network Control

```text
DB subnet group
→ defines where RDS may be placed

Security group
→ defines who may connect and on which ports

PubliclyAccessible
→ determines whether public addressing is enabled
```

These controls solve different networking problems.

---

## Secure RDS Design

A secure application-to-database architecture can be described as:

1. Create private subnets across multiple Availability Zones.
2. Add those subnets to an RDS DB subnet group.
3. Place the RDS database in that subnet group.
4. Set the database to private.
5. Create an application security group.
6. Create an RDS security group.
7. Allow PostgreSQL TCP 5432 only from the application SG.
8. Keep public Internet access disabled for RDS.

Final architecture:

```text
Internet
   │
   ▼
Application
   │
   │ TCP 5432
   ▼
RDS SG
   │
   ▼
Private PostgreSQL RDS
```

---

## Key Takeaways

- RDS is managed by AWS but still lives inside your VPC design.
- Two subnets do not mean two separate independent databases.
- Multi-AZ provides availability and failover options.
- A DB subnet group controls placement.
- A security group controls connectivity.
- `PubliclyAccessible=false` helps keep RDS private.
- NAT is for outbound Internet access, not inbound database exposure.
- SG-to-SG rules are more flexible than fixed-IP database rules.
- Database connectivity requires both network access and valid authentication.
- A resource being `available` does not guarantee end-to-end connectivity.

---
