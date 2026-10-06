# Week 7 Day 4 — Amazon RDS Fundamentals

## Objective

Learn the fundamentals of Amazon RDS by creating, connecting to, and managing a PostgreSQL database using AWS CLI and floci.

The lab focused on:

- Amazon RDS concepts
- Managed relational databases
- PostgreSQL
- RDS instance lifecycle
- RDS endpoints
- Database connectivity
- CRUD operations
- Persistence
- Troubleshooting the RDS control plane and data plane

---

## Environment

- macOS Apple Silicon
- AWS CLI
- floci
- Docker
- PostgreSQL 16.3
- `psql` client
- Region: `us-east-1`
- floci API endpoint: `http://localhost:4566`
- RDS PostgreSQL proxy endpoint: `localhost:7001`

---

## Architecture

The lab used two different connection paths.

### RDS Management Plane

```text
AWS CLI
   |
   v
localhost:4566
   |
   v
floci
   |
   v
RDS API
```

This path is used for operations such as:

- creating DB instances
- describing DB instances
- starting databases
- stopping databases

### RDS Data Plane

```text
psql
   |
   v
localhost:7001
   |
   v
floci RDS proxy
   |
   v
PostgreSQL :5432
```

The PostgreSQL server runs internally on port `5432`, while floci exposes it through an RDS proxy port.

---

## RDS Concepts Learned

### RDS Instance

An RDS instance is the managed database compute resource.

Example:

```text
week7-postgres
```

### Database Engine

The engine is the database software running on the RDS instance.

For this lab:

```text
PostgreSQL
```

### Database

The database created inside PostgreSQL was:

```text
cloudlab
```

### Table

Tables organize structured data inside a database using rows and columns.

---

## RDS vs Self-Managed Database on EC2

With a database installed manually on EC2, the administrator is responsible for more infrastructure management.

Typical responsibilities include:

- operating system maintenance
- database installation
- patching
- backups
- database host maintenance
- monitoring

RDS reduces much of this infrastructure work.

The user still remains responsible for:

- database design
- tables
- indexes
- SQL queries
- users and permissions
- application credentials
- application data
- network access configuration

---

## Create the RDS Instance

Environment variables:

```bash
export DB_INSTANCE_ID=week7-postgres
export DB_NAME=cloudlab
export DB_USERNAME=cloudadmin
export DB_PASSWORD='CloudLab123!'
```

The PostgreSQL instance was created with:

```bash
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username "$DB_USERNAME" \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --db-name "$DB_NAME" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

## Inspect the RDS Instance

```bash
aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Useful filtered output:

```bash
aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query "DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint}" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Final endpoint:

```text
Address: localhost
Port: 7001
```

---

## Database Connection Parameters

An application typically needs five main database connection values:

```text
DB_HOST
DB_PORT
DB_DATABASE
DB_USERNAME
DB_PASSWORD
```

For this lab:

```text
DB_HOST=localhost
DB_PORT=7001
DB_DATABASE=cloudlab
DB_USERNAME=cloudadmin
DB_PASSWORD=<local lab password>
```

---

## Test TCP Connectivity

```bash
nc -zv 127.0.0.1 7001
```

Successful output confirmed that the RDS proxy port was reachable.

---

## Connect with PostgreSQL Client

```bash
PGPASSWORD="$DB_PASSWORD" psql \
  -h 127.0.0.1 \
  -p "$DB_PORT" \
  -U "$DB_USERNAME" \
  -d "$DB_NAME"
```

Successful connection:

```text
psql 18.6, server 16.3
SSL connection using TLSv1.3

cloudlab=#
```

---

## PostgreSQL Verification

Inside `psql`:

```sql
SELECT version();
```

```sql
SELECT current_database();
```

```sql
SELECT current_user;
```

---

## CRUD Lab

### Create Table

```sql
CREATE TABLE cloud_projects (
    id SERIAL PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    cloud_provider VARCHAR(50) NOT NULL,
    status VARCHAR(30) NOT NULL
);
```

### Insert Data

```sql
INSERT INTO cloud_projects
(project_name, cloud_provider, status)
VALUES
('12 Week Cloud Engineering Journey', 'AWS', 'In Progress');
```

```sql
INSERT INTO cloud_projects
(project_name, cloud_provider, status)
VALUES
('Week 7 RDS Lab', 'AWS', 'Active');
```

### Read Data

```sql
SELECT * FROM cloud_projects;
```

### Update Data

```sql
UPDATE cloud_projects
SET status = 'Completed'
WHERE project_name = 'Week 7 RDS Lab';
```

### Delete Data

```sql
DELETE FROM cloud_projects
WHERE project_name = 'Temporary Lab';
```

---

## Independent Challenge — cloud_services

A second table was created to practice CRUD independently.

```sql
CREATE TABLE cloud_services (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    service_category VARCHAR(100) NOT NULL,
    week_learned VARCHAR(100) NOT NULL
);
```

Final data included:

```text
EC2 → Compute → Week 3
S3  → Storage → Week 7
RDS → Database → Week 7
```

Operations practiced:

- `CREATE TABLE`
- `INSERT INTO`
- `SELECT`
- `UPDATE`
- `DELETE`

---

## psql Prompt Behavior

Two prompt states were observed.

```text
cloudlab=#
```

means `psql` is ready for a new command.

```text
cloudlab-#
```

means the previous SQL statement has not been completed.

Most commonly this happens when the semicolon is missing.

Example:

```sql
SELECT * FROM cloud_services
```

causes `psql` to wait for more input.

The query buffer can be reset with:

```text
\r
```

or cancelled with:

```text
Ctrl+C
```

To clear the terminal from inside `psql`:

```text
\! clear
```

---

## RDS Lifecycle

RDS instances have lifecycle states such as:

```text
creating
available
stopping
stopped
starting
deleting
```

Stopping database compute does not necessarily delete persistent database data.

The PostgreSQL backend uses persistent Docker storage, so database data can survive compute restarts.

---

# Troubleshooting

## Problem

The RDS instance reported:

```text
available
```

but PostgreSQL connections failed.

Initial symptoms included:

```text
connection refused
```

and:

```text
server closed the connection unexpectedly
```

---

## Investigation

The PostgreSQL backend container itself was healthy.

```bash
docker exec \
  floci-rds-db-... \
  pg_isready -h 127.0.0.1 -p 5432
```

Result:

```text
127.0.0.1:5432 - accepting connections
```

Direct authentication also succeeded:

```text
cloudadmin | cloudlab
```

This proved:

```text
PostgreSQL backend  ✅
Credentials         ✅
Database            ✅
```

The remaining problem was therefore the floci RDS proxy path.

---

## Root Cause

Two different floci control-plane containers were running.

One container handled:

```text
localhost:4566
```

while another container handled:

```text
7001-7099
```

This split the RDS control plane from the RDS data-plane proxy.

The old control-plane container also did not have the required RDS endpoint settings.

---

## Additional Persistence Issue

The original floci container used in-memory state.

Although `/app/data` was mounted, mounting storage alone does not mean the application is actually persisting its metadata.

The environment was changed to:

```text
FLOCI_STORAGE_MODE=hybrid
FLOCI_STORAGE_PERSISTENT_PATH=/app/data
```

This allowed floci metadata to survive container recreation.

---

## Final floci Configuration

The final control-plane container exposes:

```text
4566
6379-6399
7001-7099
9200-9299
```

Important environment settings:

```text
FLOCI_STORAGE_MODE=hybrid
FLOCI_STORAGE_PERSISTENT_PATH=/app/data
FLOCI_SERVICES_RDS_PROXY_BASE_PORT=7001
FLOCI_SERVICES_RDS_ENDPOINT_HOST=localhost
```

The original lab state directory was preserved:

```text
~/cloud-engineering-journey/.floci-data
```

A backup was also created before modifying the container.

---

## Final Result

RDS successfully returned:

```text
Address: localhost
Port: 7001
```

TCP connectivity succeeded:

```text
Connection to 127.0.0.1 port 7001 succeeded
```

PostgreSQL connection succeeded:

```text
cloudlab=#
```

The final working architecture became:

```text
Mac
 |
 +--> localhost:4566
 |       |
 |       v
 |     floci API
 |
 +--> localhost:7001
         |
         v
      RDS proxy
         |
         v
    PostgreSQL :5432
```

---

## Key Lessons

- RDS is a managed relational database service.
- PostgreSQL was used as the database engine.
- An RDS instance, database engine, database, and table represent different layers.
- `localhost:4566` is the floci management API.
- `localhost:7001` is the RDS PostgreSQL data endpoint.
- An `available` resource state does not guarantee end-to-end connectivity.
- Database troubleshooting should separate control plane, networking, proxy, authentication, and backend health.
- Persistent storage requires both durable storage and application configuration that actually writes state there.
- Docker port exposure and internal container ports are different concepts.
- CRUD stands for Create, Read, Update, and Delete.

---

