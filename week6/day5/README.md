# Week 6 Day 5 — Docker Compose

## Objective

Learn how Docker Compose simplifies multi-container application management by defining services, networks, volumes, environment variables, dependencies, and runtime configuration in a single YAML file.

Topics covered:

- `compose.yaml`
- Services
- Automatic project networks
- Multi-container communication
- Docker DNS
- Environment variables
- Named volumes
- Persistent data
- `depends_on`
- `docker compose up`
- `docker compose down`
- `docker compose stop/start`
- Compose logs
- Compose exec
- Project naming
- Compose-managed resource names

---

# Why Docker Compose?

Without Compose, a multi-container application may require multiple commands:

```text
docker network create ...
docker volume create ...
docker run ...
docker run ...
docker run ...
```

Docker Compose allows the full application stack to be defined in one file:

```text
compose.yaml
   |
   +-- web
   +-- backend
   +-- network
   +-- volume
   +-- environment
```

Then launched using:

```bash
docker compose up -d
```

---

# Project Structure

The project was created under:

```text
week6/day5/app
```

Files included:

```text
app/
├── Dockerfile
├── index.html
└── compose.yaml
```

---

# Web Application

The web page contained:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Week 6 Docker Compose</title>
</head>
<body>
    <h1>Week 6 Day 5</h1>
    <h2>Docker Compose</h2>
    <p>This container was started using Docker Compose.</p>
</body>
</html>
```

---

# Dockerfile

The web image used:

```dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

---

# First Compose File

The initial `compose.yaml` contained one service:

```yaml
services:
  web:
    build: .
    container_name: week6-compose-web
    ports:
      - "8090:80"
```

This defined a service named:

```text
web
```

with:

```text
build context:
current directory

container name:
week6-compose-web

host port:
8090

container port:
80
```

---

# Validate Compose Configuration

The file was validated using:

```bash
docker compose config
```

Docker interpreted the configuration as:

```text
Project name:
app

Service:
web

Default network:
app_default
```

Compose derived the project name from the directory name:

```text
app
```

---

# Start Compose Application

The stack was launched:

```bash
docker compose up -d
```

Compose automatically created:

```text
app_default network
week6-compose-web container
```

The application was verified:

```bash
curl http://localhost:8090
```

Result:

```text
Week 6 Day 5
Docker Compose
```

---

# Compose Project Naming

Compose used the project name:

```text
app
```

This influenced resource names.

For example:

```text
service:
web

built image:
app-web

network:
app_default
```

Later:

```text
volume:
backend-data

Docker volume:
app_backend-data
```

Compose scopes resources using the project name.

---

# Add Backend Service

The Compose file was expanded:

```yaml
services:
  web:
    build: .
    container_name: week6-compose-web
    ports:
      - "8090:80"

  backend:
    image: python:3.12-alpine
    container_name: week6-compose-backend
    command: python -m http.server 8000
```

Then:

```bash
docker compose up -d
```

created the backend while keeping the existing web service running.

---

# Compose Service

A service defines one application workload.

Examples:

```text
web
backend
database
redis
worker
```

Each service can define:

```text
image
build
command
ports
environment
volumes
networks
depends_on
```

---

# Automatic Network Creation

Compose created:

```text
app_default
```

automatically.

Both services joined that network.

Inspection showed:

```text
week6-compose-web     -> 172.22.0.2
week6-compose-backend -> 172.22.0.3
```

---

# Docker DNS in Compose

From the `web` container:

```bash
getent hosts backend
```

resolved:

```text
backend -> 172.22.0.3
```

This demonstrated automatic service-name DNS.

Conceptually:

```text
web
 |
 | backend
 v
Docker DNS
 |
 v
172.22.0.3
```

---

# Internal Service Communication

The web service called:

```bash
curl http://backend:8000
```

and successfully reached the backend.

Traffic path:

```text
web container
      |
      v
backend:8000
      |
      v
Compose DNS
      |
      v
backend container
      |
      v
Python HTTP server
```

---

# Backend Not Published to Host

This failed from the Mac:

```bash
curl http://localhost:8000
```

because the backend did not define:

```yaml
ports:
  - "8000:8000"
```

Therefore:

```text
Host → web:8090        ✅
web → backend:8000     ✅
Host → backend:8000    ❌
```

This demonstrated an internal-only service.

---

# Environment Variables

The web service was configured with:

```yaml
environment:
  APP_ENV: development
  BACKEND_HOST: backend
  BACKEND_PORT: "8000"
```

Inside the container:

```text
APP_ENV=development
BACKEND_HOST=backend
BACKEND_PORT=8000
```

Environment variables allow runtime application configuration without hardcoding values into the image.

---

# Environment-Driven Architecture

Instead of hardcoding:

```text
backend IP = 172.22.0.3
```

the configuration used:

```text
BACKEND_HOST=backend
```

Docker DNS then resolved the service dynamically.

---

# Add Named Volume

The backend service was updated:

```yaml
backend:
  image: python:3.12-alpine
  container_name: week6-compose-backend
  command: python -m http.server 8000 --directory /data
  volumes:
    - backend-data:/data
```

And the top-level volume definition was added:

```yaml
volumes:
  backend-data:
```

Compose created:

```text
app_backend-data
```

---

# Compose Volume Naming

The declared volume:

```text
backend-data
```

was transformed into:

```text
app_backend-data
```

using:

```text
project name + volume name
```

Conceptually:

```text
app
+
backend-data
=
app_backend-data
```

---

# Persistent Backend Data

Data was written into:

```text
/data/index.html
```

using:

```bash
docker compose exec backend \
  sh -c 'echo "Docker Compose persistent data" > /data/index.html'
```

The web service retrieved it:

```bash
docker compose exec web \
  curl http://backend:8000
```

Result:

```text
Docker Compose persistent data
```

---

# Full Data Flow

```text
web
 |
 | HTTP
 v
backend:8000
 |
 v
/data/index.html
 |
 v
app_backend-data
```

---

# depends_on

The web service defined:

```yaml
depends_on:
  - backend
```

This tells Compose that `web` depends on `backend`.

Conceptually:

```text
backend starts
     ↓
web starts
```

Important:

```text
depends_on
does not automatically mean
backend is application-ready
```

For real readiness, health checks are preferred.

---

# Compose Down Test

The application stack was removed:

```bash
docker compose down
```

Compose removed:

```text
week6-compose-web
week6-compose-backend
app_default
```

but did not remove:

```text
app_backend-data
```

---

# Persistent Volume Survived

After:

```bash
docker compose down
```

the volume still appeared:

```bash
docker volume ls | grep backend
```

Result:

```text
app_backend-data
```

---

# Recreate Entire Stack

The stack was recreated:

```bash
docker compose up -d
```

Compose created:

```text
new app_default network
new web container
new backend container
```

while reusing:

```text
app_backend-data
```

---

# Verify Data After Recreation

The backend still contained:

```text
Docker Compose persistent data
```

Verification:

```bash
docker compose exec backend \
  cat /data/index.html
```

and:

```bash
docker compose exec web \
  curl http://backend:8000
```

both returned the original data.

---

# Container Lifecycle vs Volume Lifecycle

The lab demonstrated:

```text
containers deleted
      ↓
network deleted
      ↓
volume remains
      ↓
containers recreated
      ↓
same volume attached
      ↓
data still available
```

Key principle:

```text
Container lifecycle
       ≠
Volume lifecycle
```

---

# How Compose Recognizes Its Volume

Compose uses predictable project-scoped names and labels.

Example:

```text
Project:
app

Compose volume key:
backend-data

Docker resource:
app_backend-data
```

Compose metadata also identifies the resource as belonging to the project.

Conceptually:

```text
Name:
app_backend-data

Labels:
project=app
volume=backend-data
```

---

# Inspect Compose Volume Labels

Example:

```bash
docker volume inspect app_backend-data \
  --format '{{json .Labels}}'
```

These labels help Compose manage project resources.

---

# docker compose stop

```bash
docker compose stop
```

stops containers but keeps them.

Conceptually:

```text
running containers
      ↓
stopped containers
```

The containers still exist.

---

# docker compose start

Stopped Compose containers can be started again:

```bash
docker compose start
```

---

# docker compose down

```bash
docker compose down
```

removes:

```text
containers
Compose network
```

but keeps named volumes by default.

---

# docker compose down -v

```bash
docker compose down -v
```

removes:

```text
containers
network
named volumes
```

This should be used carefully when persistent data matters.

---

# Compose Exec

Commands can be run using service names:

```bash
docker compose exec web sh
```

or:

```bash
docker compose exec backend sh
```

This is often easier than using container IDs or manually created container names.

---

# Compose Logs

View all service logs:

```bash
docker compose logs
```

Follow logs:

```bash
docker compose logs -f
```

Specific service:

```bash
docker compose logs web
```

```bash
docker compose logs backend
```

---

# Compose Restart

Restart all services:

```bash
docker compose restart
```

Restart one service:

```bash
docker compose restart backend
```

---

# Compose Troubleshooting Workflow

Useful commands:

```text
docker compose config
        ↓
validate configuration

docker compose ps
        ↓
check service states

docker compose logs
        ↓
inspect application output

docker compose exec
        ↓
inspect service internally

docker network inspect
        ↓
check connectivity

docker volume inspect
        ↓
check storage
```

---

# Knowledge Check Summary

## Why Compose?

Compose manages related containers and supporting resources from one configuration file.

---

## Service

A service defines one application component.

---

## Compose Up

```bash
docker compose up -d
```

creates/starts needed:

```text
containers
networks
volumes
```

---

## Compose DNS

Services on the same Compose network can communicate using service names.

Example:

```text
backend
```

instead of:

```text
172.22.0.3
```

---

## Internal-Only Services

A container does not need a host-published port to communicate with another container on the same Compose network.

---

## Environment Variables

Environment variables provide runtime configuration.

---

## depends_on

Defines service startup dependency/order.

It does not automatically guarantee application readiness.

---

## Stop vs Down

```text
docker compose stop
→ stop containers

docker compose down
→ remove containers and network
```

---

## Named Volumes

Named volumes persist independently of the containers.

---

## Down vs Down -v

```text
docker compose down
→ keep named volumes

docker compose down -v
→ remove named volumes
```

---

# Day 5 Mental Model

```text
compose.yaml
      |
      +-- services
      +-- environment
      +-- networks
      +-- volumes
      +-- dependencies
      |
      v
docker compose up
```

And:

```text
service name
     ↓
Docker DNS
     ↓
service IP
```

Most importantly:

```text
Containers are replaceable.

Persistent data belongs
outside the container lifecycle.
```

---

# Final Result

Successfully demonstrated:

```text
Create Compose file                   ✅
Validate Compose configuration        ✅
Build service image                   ✅
Start Compose application             ✅
Automatic network creation            ✅
Multiple services                     ✅
Compose DNS                           ✅
Service-name communication            ✅
Internal-only backend                 ✅
Environment variables                 ✅
depends_on                            ✅
Named volume                          ✅
Persistent backend storage            ✅
Compose project naming                ✅
Volume project association            ✅
docker compose down                   ✅
Recreate containers/network           ✅
Data survives recreation              ✅
Compose lifecycle concepts            ✅
```
