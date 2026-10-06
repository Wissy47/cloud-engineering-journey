# Week 7 Day 6 — Route 53 & DNS

## Objective

Learn how DNS works in AWS using Amazon Route 53 and connect DNS concepts to the RDS and VPC architecture built earlier in Week 7.

The lab covered:

- DNS resolution
- Route 53
- Hosted zones
- Public vs private DNS
- A records
- CNAME records
- TTL
- NS and SOA records
- DNS abstraction
- Routing policies
- floci DNS limitations

---

## Environment

- macOS Apple Silicon
- AWS CLI
- floci
- Region: `us-east-1`
- floci endpoint:

```text
http://localhost:4566
```

Private DNS namespace:

```text
cloudlab.internal
```

---

# DNS Fundamentals

DNS allows applications and users to use names instead of remembering IP addresses.

Example:

```text
app.cloudlab.internal
        ↓
DNS
        ↓
10.40.1.50
```

A useful way to think about DNS is:

```text
Name → location
```

The name can remain stable even if the underlying infrastructure changes.

---

# Amazon Route 53

Amazon Route 53 is AWS's managed DNS service.

It can manage:

- hosted zones
- DNS records
- public DNS
- private DNS
- traffic routing policies
- health-based routing

---

# Hosted Zones

A hosted zone is a container for DNS records belonging to a domain or DNS namespace.

For this lab:

```text
cloudlab.internal
```

was used as the DNS namespace.

---

## Public Hosted Zone

A public hosted zone is used for DNS records that should be resolvable publicly.

Example:

```text
example.com
www.example.com
api.example.com
```

---

## Private Hosted Zone

A private hosted zone is used for DNS names that should only be available inside associated VPCs.

Our lab used:

```text
cloudlab.internal
```

Conceptually:

```text
VPC
│
├── app.cloudlab.internal
├── api.cloudlab.internal
└── db.cloudlab.internal
```

---

# Create the Private Hosted Zone

Environment variables:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

export PRIVATE_DOMAIN=cloudlab.internal
export WEEK4_VPC_ID=vpc-c1d0eaf8
```

The private hosted zone was created with:

```bash
aws route53 create-hosted-zone \
  --name "$PRIVATE_DOMAIN" \
  --caller-reference "week7-day6-$(date +%s)" \
  --hosted-zone-config PrivateZone=true \
  --vpc VPCRegion=us-east-1,VPCId="$WEEK4_VPC_ID" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

The hosted zone ID was captured using:

```bash
export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$PRIVATE_DOMAIN" \
  --query "HostedZones[0].Id" \
  --output text \
  --endpoint-url "$AWS_ENDPOINT_URL")
```

---

# DNS Record Types

## A Record

An A record maps a hostname to an IPv4 address.

Example:

```text
app.cloudlab.internal
        ↓
10.40.1.50
```

Memory rule:

```text
A → name → IPv4
```

---

## CNAME Record

A CNAME maps one hostname to another hostname.

Example:

```text
db.cloudlab.internal
        ↓
RDS hostname
```

Memory rule:

```text
CNAME → name → name
```

---

## NS Record

NS means:

```text
Name Server
```

It identifies the authoritative DNS servers for the hosted zone.

---

## SOA Record

SOA means:

```text
Start of Authority
```

It contains administrative information about the DNS zone.

The NS and SOA records were created automatically when the hosted zone was created.

---

# TTL

TTL means:

```text
Time To Live
```

TTL tells DNS resolvers how long they may cache a DNS answer.

For the lab:

```text
TTL = 300
```

which means:

```text
300 seconds = 5 minutes
```

---

## Low vs High TTL

Low TTL:

```text
changes become visible sooner
more DNS queries
```

High TTL:

```text
more caching
fewer queries
changes take longer to be seen
```

---

# Application A Record

The application DNS record was created as:

```text
app.cloudlab.internal
A
10.40.1.50
TTL 300
```

Configuration file:

```json
{
  "Comment": "Week 7 Day 6 internal application DNS",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.cloudlab.internal",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "10.40.1.50"
          }
        ]
      }
    }
  ]
}
```

---

# API A Record

The API record was created independently as part of the hands-on challenge.

```text
api.cloudlab.internal
A
10.40.1.60
TTL 300
```

Configuration:

```json
{
  "Comment": "Internal api DNS",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.cloudlab.internal",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "10.40.1.60"
          }
        ]
      }
    }
  ]
}
```

The record was applied with:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch file://api-record.json \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Result:

```text
Status: INSYNC
```

---

# Database CNAME

The database record was configured as:

```text
db.cloudlab.internal
CNAME
localhost
TTL 300
```

The `localhost` value is specific to the floci RDS implementation used in the lab.

On real AWS, the destination would normally be an RDS-generated hostname.

Conceptually:

```text
db.cloudlab.internal
        ↓
RDS endpoint
```

---

# Final DNS Records

The hosted zone contained:

```text
api.cloudlab.internal.
A
10.40.1.60
TTL 300
```

```text
app.cloudlab.internal.
A
10.40.1.50
TTL 300
```

```text
db.cloudlab.internal.
CNAME
localhost
TTL 300
```

It also contained automatically generated:

```text
NS
SOA
```

records.

---

# Why Use a Custom Database DNS Name?

Instead of configuring every application with an infrastructure-specific hostname:

```text
mydb.xxxxx.us-east-1.rds.amazonaws.com
```

applications can use:

```text
db.cloudlab.internal
```

Conceptually:

```text
Application
     │
     ▼
db.cloudlab.internal
     │
     ▼
Route 53
     │
     ▼
RDS endpoint
```

If the underlying RDS endpoint changes later:

```text
db.cloudlab.internal
       ↓
New RDS
```

the application can continue using the same DNS name.

This provides abstraction between the application and infrastructure.

---

# UPSERT

Route 53 supports the `UPSERT` action.

This means:

```text
record exists
→ update it

record does not exist
→ create it
```

This is useful when managing changing infrastructure.

---

# DNS Does Not Equal Connectivity

Successful DNS resolution only answers:

```text
Where is the resource?
```

It does not guarantee access.

The complete path looks like:

```text
Application
    ↓
db.cloudlab.internal
    ↓
Route 53
    ↓
RDS endpoint
    ↓
Routing
    ↓
Security Group
    ↓
PostgreSQL
    ↓
Database Authentication
```

Each layer must succeed.

---

# DNS vs Networking vs Authentication

## DNS

Question:

```text
Where is the resource?
```

Example:

```text
db.cloudlab.internal
→ RDS endpoint
```

---

## Network Authorization

Question:

```text
Is this traffic allowed to reach the resource?
```

Controlled by things such as:

- VPC
- subnets
- routes
- security groups
- ports

---

## Database Authentication

Question:

```text
Is this user allowed to log in?
```

Controlled by:

- username
- password
- database roles
- IAM authentication where applicable

---

# Route 53 Routing Policies

## Simple Routing

Used when one normal destination handles the traffic.

```text
app.example.com
       ↓
Server A
```

---

## Weighted Routing

Used to split traffic between destinations.

Example:

```text
90% → Application A
10% → Application B
```

Useful for:

- gradual rollouts
- canary deployments
- testing new versions

---

## Failover Routing

Used when there is a primary and backup destination.

```text
Primary healthy?
     │
     ├── Yes → Primary
     │
     └── No  → Secondary
```

This is different from RDS Multi-AZ.

```text
Route 53 failover
→ DNS-level traffic routing

RDS Multi-AZ
→ database infrastructure failover
```

---

# DNS Troubleshooting

If a DNS name does not work, troubleshoot in layers:

```text
1. Does the hosted zone exist?
2. Does the DNS record exist?
3. Is the record type correct?
4. Is the destination correct?
5. Is the VPC associated with the zone?
6. Is the correct DNS resolver being used?
7. Is DNS caching or TTL involved?
8. Is the destination itself reachable?
```

---

# floci Limitation

The Route 53 API inside floci can successfully store DNS records.

However, the Mac's operating-system DNS resolver does not necessarily query the floci private hosted zone automatically.

Therefore:

```bash
dig app.cloudlab.internal
```

may fail even when:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

shows that the record exists.

This demonstrates an important difference between:

```text
AWS control-plane state
```

and:

```text
local operating-system DNS resolution
```

---

# Final Architecture

```text
Application
    │
    ▼
db.cloudlab.internal
    │
    ▼
Route 53
    │
    ▼
RDS Endpoint
    │
    ▼
Security Group
    │
    ▼
PostgreSQL
    │
    ▼
Database Authentication
```

---

# Key Lessons

- DNS converts names into destinations.
- Route 53 is AWS's managed DNS service.
- Hosted zones contain DNS records.
- Public hosted zones serve public DNS.
- Private hosted zones provide internal VPC DNS.
- A records map names to IPv4 addresses.
- CNAME records map names to other hostnames.
- TTL controls DNS caching time.
- `UPSERT` creates or updates a DNS record.
- NS records identify authoritative name servers.
- SOA records contain DNS zone administration information.
- DNS resolution does not guarantee network connectivity.
- Weighted routing distributes traffic by weight.
- Failover routing sends traffic to a backup when a primary resource fails.
- DNS names provide abstraction from infrastructure-specific endpoints.
- floci's DNS control plane does not automatically become the Mac's DNS resolver.

---
