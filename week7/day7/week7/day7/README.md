# Week 7 Day 7 — Secure Cloud Application Data Layer Mini Project

## Objective

Build a small cloud application data architecture that combines the main services and concepts from Week 7:

- Amazon S3
- Amazon RDS PostgreSQL
- Amazon VPC
- Security Groups
- Amazon Route 53
- DNS
- Object versioning
- Private database access

The goal was to prove that the Week 7 topics work together as one architecture rather than as isolated labs.

---

## Project Scenario

The project models a small cloud application called:

```text
CloudLab Project Tracker
```

The application stores:

- files and evidence in S3
- structured project data in PostgreSQL
- database traffic through private RDS networking
- an internal database name through Route 53

---

## Final Architecture

```text
                    Application
                       │
          ┌────────────┴────────────┐
          │                         │
          ▼                         ▼
         S3                    Route 53
   Object Storage         db.cloudlab.internal
                                    │
                                    ▼
                              RDS Endpoint
                                    │
                                    ▼
                              RDS Security Group
                                    │
                               TCP 5432
                                    │
                                    ▼
                           PostgreSQL Database
```

Networking model:

```text
VPC 10.40.0.0/16

Application Tier
    │
    │ App SG
    │
    │ TCP 5432
    ▼
RDS Security Group
    │
    ▼
Private RDS
    │
DB Subnet Group
├── Private Subnet A
└── Private Subnet B
```

---

## Project Workspace

Created:

```text
week7/day7/
├── database/
├── dns/
├── evidence/
└── s3/
```

Commands:

```bash
mkdir -p week7/day7
cd week7/day7

mkdir -p \
  s3 \
  database \
  dns \
  evidence
```

---

## Environment

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

The lab used:

- AWS CLI
- floci
- Docker
- PostgreSQL
- psql
- Route 53
- S3
- RDS
- EC2 networking APIs

---

# Database Layer

The project used the private PostgreSQL instance created during the RDS networking lab.

Example:

```text
week7-private-postgres
```

The RDS endpoint and port were retrieved dynamically rather than assumed.

```bash
export PROJECT_DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier "$PROJECT_DB_INSTANCE" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text \
  --endpoint-url "$AWS_ENDPOINT_URL")
```

```bash
export PROJECT_DB_PORT=$(aws rds describe-db-instances \
  --db-instance-identifier "$PROJECT_DB_INSTANCE" \
  --query "DBInstances[0].Endpoint.Port" \
  --output text \
  --endpoint-url "$AWS_ENDPOINT_URL")
```

This is important because floci can assign proxy ports dynamically.

---

## PostgreSQL Connection

The database connection was verified using `psql`.

```bash
psql \
  -h 127.0.0.1 \
  -p "$PROJECT_DB_PORT" \
  -U "$DB_USERNAME" \
  -d "$DB_NAME"
```

Successful connection:

```text
psql 18.6, server 16.3

SSL connection
protocol: TLSv1.3
cipher: TLS_AES_256_GCM_SHA384
```

---

## Projects Table

A relational table was created:

```sql
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    project_name VARCHAR(150) NOT NULL,
    project_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    storage_location VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## Project Records

The following rows were stored:

```text
Cloud Engineering Journey
Cloud Infrastructure
Active
S3
```

```text
Week 7 Mini Project
AWS Storage Database DNS
In Progress
S3
```

The independent challenge added:

```text
Secure RDS Architecture
Networking
Completed
S3
```

Final query:

```sql
SELECT * FROM projects;
```

Result:

```text
Cloud Engineering Journey
Week 7 Mini Project
Secure RDS Architecture
```

This demonstrated structured relational storage with PostgreSQL.

---

# Why RDS Was Used

RDS was used for structured data such as:

- project names
- project status
- project types
- relationships
- timestamps

Relational databases are appropriate when data needs:

- tables
- SQL queries
- relationships
- constraints
- structured schemas

---

# S3 Object Storage Layer

S3 was used for application files and project evidence.

Bucket:

```text
week7-cloud-project-evidence
```

---

## Enable Versioning

Versioning was enabled:

```bash
aws s3api put-bucket-versioning \
  --bucket "$PROJECT_BUCKET" \
  --versioning-configuration Status=Enabled \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Versioning protects against:

- accidental overwrites
- accidental deletion
- unwanted file replacement

Older versions can be recovered.

---

## Project Summary Object

Created:

```text
s3/project-summary.txt
```

Uploaded to:

```text
s3://week7-cloud-project-evidence/evidence/project-summary.txt
```

---

## Versioning Test

The file was changed and uploaded again.

Object versions were inspected with:

```bash
aws s3api list-object-versions \
  --bucket "$PROJECT_BUCKET" \
  --prefix evidence/project-summary.txt \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Multiple VersionIds confirmed that versioning was working.

---

# Architecture Notes Challenge

An additional object was created:

```text
s3/architecture-notes.txt
```

It described:

- why RDS is private
- why App SG is referenced by RDS SG
- why Route 53 is used
- why S3 versioning is enabled

The file was uploaded to:

```text
s3://week7-cloud-project-evidence/documentation/architecture-notes.txt
```

Verification:

```text
architecture-notes.txt
```

was successfully listed from the bucket.

---

# Why S3 Was Used

S3 was used for:

- files
- documents
- evidence
- logs
- architecture notes

Unlike RDS, S3 is object storage.

It does not require relational tables or structured schemas.

---

# Object Storage vs Relational Storage

```text
S3
→ files and objects
```

```text
RDS
→ structured relational data
```

Examples:

```text
Screenshot → S3
Project row → RDS
README artifact → S3
Project status → RDS
```

---

# Private RDS Networking

The database follows a private-networking design.

```text
Application SG
      │
      │ TCP 5432
      ▼
RDS SG
      │
      ▼
Private PostgreSQL
```

The RDS security group does not use:

```text
0.0.0.0/0 → 5432
```

Instead, the source is the application security group.

This follows least-privilege networking.

---

# Why RDS Is Private

The application and database communicate internally.

There is no need to expose PostgreSQL directly to the public Internet.

Keeping RDS private:

- reduces attack surface
- prevents direct public database access
- allows application-tier controlled access
- improves network isolation

---

# DB Subnet Group

The DB subnet group defines where RDS may be placed inside the VPC.

Conceptually:

```text
DB Subnet Group
├── Private Subnet A
└── Private Subnet B
```

Using multiple Availability Zones gives AWS multiple placement options and supports highly available designs.

Two subnets do not automatically mean two separate independent databases.

---

# Route 53 DNS

The application uses an internal DNS name:

```text
db.cloudlab.internal
```

instead of depending directly on the infrastructure-generated database hostname.

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
RDS Endpoint
```

This creates abstraction.

If the underlying database endpoint changes, the application can continue using:

```text
db.cloudlab.internal
```

---

# DNS, Networking and Authentication

These operate at different layers.

## DNS

Question:

```text
Where is the database?
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
Is the application allowed to reach PostgreSQL?
```

Controlled by:

- VPC
- subnets
- routing
- security groups
- TCP ports

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
- IAM DB authentication where applicable

All three layers must work.

---

# Route 53 Routing Policies

## Simple Routing

One normal destination.

```text
app.example.com
→ Application A
```

---

## Weighted Routing

Traffic is distributed based on configured weights.

Example:

```text
90% → Application A
10% → Application B
```

Useful for:

- canary deployments
- gradual rollout
- testing new versions

---

## Failover Routing

Traffic normally goes to a primary resource.

If the primary becomes unhealthy:

```text
Primary
    ↓ failure
Secondary
```

This is DNS-level failover.

---

# TTL

TTL means:

```text
Time To Live
```

It determines how long DNS answers may be cached.

Example:

```text
TTL 300
```

means approximately:

```text
5 minutes
```

Lower TTL:

```text
faster updates
more DNS queries
```

Higher TTL:

```text
more caching
slower changes
```

---

# Troubleshooting Methodology

If the application cannot connect to RDS, troubleshoot layer by layer.

```text
1. RDS state
2. Endpoint
3. DNS
4. Routing
5. Security group
6. TCP port
7. TLS
8. Credentials
9. Target database
```

Do not assume:

```text
RDS = available
```

means:

```text
Application connection = working
```

---

# floci vs Real AWS

floci exposes RDS through local proxy ports such as:

```text
localhost:7001
localhost:7002
localhost:7003
```

This allows the Mac to reach the local PostgreSQL backend.

Therefore, even though the RDS architecture is modeled as private:

```text
PubliclyAccessible=false
```

the database may still be reachable through localhost.

This is emulator behavior.

It does not mean that a real private RDS instance in AWS would be directly reachable from a laptop on the public Internet.

---

# Evidence Collection

RDS:

```bash
aws rds describe-db-instances \
  --db-instance-identifier "$PROJECT_DB_INSTANCE" \
  --endpoint-url "$AWS_ENDPOINT_URL" \
  > evidence/rds-instance.json
```

S3 versions:

```bash
aws s3api list-object-versions \
  --bucket "$PROJECT_BUCKET" \
  --endpoint-url "$AWS_ENDPOINT_URL" \
  > evidence/s3-versions.json
```

Route 53:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --endpoint-url "$AWS_ENDPOINT_URL" \
  > evidence/route53-records.json
```

Security Groups:

```bash
aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values=vpc-c1d0eaf8 \
  --endpoint-url "$AWS_ENDPOINT_URL" \
  > evidence/security-groups.json
```

---

# Key Lessons

- S3 is object storage.
- RDS is relational database storage.
- Use S3 for files and RDS for structured relational data.
- S3 versioning protects object history.
- RDS should generally stay private when only internal applications require access.
- A DB subnet group defines allowed RDS placement.
- Security groups provide network access control.
- App SG → RDS SG is safer than opening PostgreSQL to the Internet.
- Route 53 provides DNS abstraction.
- DNS finds the service.
- Networking determines whether traffic can reach it.
- Authentication determines whether the user can access it.
- Weighted routing splits traffic.
- Failover routing provides DNS-level backup behavior.
- floci's localhost proxy behavior differs from real AWS networking.

---

# Final Project Architecture

```text
                  CloudLab Application
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
             S3                    Route 53
       Object Storage          db.cloudlab.internal
              │                         │
       ┌──────┴──────┐                  ▼
       │             │              RDS Endpoint
   Evidence     Documentation            │
                                          ▼
                                     RDS SG
                                          │
                                     TCP 5432
                                          │
                                          ▼
                               Private PostgreSQL RDS
```

---

## Week 7 Completion

```text
Week 7 — AWS Storage, Databases & DNS

Day 1 ✅ S3 Fundamentals
Day 2 ✅ S3 Versioning, Lifecycle & Security
Day 3 ✅ Advanced S3
Day 4 ✅ Amazon RDS Fundamentals
Day 5 ✅ RDS Networking & Security
Day 6 ✅ Route 53 & DNS
Day 7 ✅ Secure Cloud Application Mini Project
```
