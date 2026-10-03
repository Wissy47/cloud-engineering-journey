# Week 6 Day 7 — Containerized Application Mini-Project

## Objective

Combine the Docker concepts from Week 6 into one small multi-container application.

The mini-project includes:

- Custom Docker image
- Dockerfile
- Docker Compose
- Multiple services
- Custom Docker network
- Docker DNS
- Environment variables
- Health checks
- `depends_on`
- Bind mounts
- Named volumes
- Persistent data
- Container recreation
- Container registry
- AWS ECR workflow
- Image tagging
- Image push
- Registry verification

The final architecture was:

```text id="xfzh88"
Mac / Browser
      |
      | localhost:8091
      v
Nginx Web Container
      |
      | backend:8000
      | Docker DNS
      v
Python Backend Container
      |
      v
/data
      |
      v
Named Volume
backend-data
```

The frontend image was also distributed through the local ECR-compatible registry:

```text id="ktdc1i"
Dockerfile
    ↓
docker build
    ↓
app-web:latest
    ↓
docker tag
    ↓
week6-day7-web:v1
    ↓
docker push
    ↓
ECR / OCI Registry
```

---

# Project Structure

The project was created under:

```text id="5svao8"
week6/day7/app
```

Initial structure:

```text id="hcqc1d"
app/
├── Dockerfile
├── index.html
└── backend/
    └── start.sh
```

Later:

```text id="26zkvc"
app/
├── Dockerfile
├── compose.yaml
├── index.html
└── backend/
    └── start.sh
```

---

# Frontend HTML

The frontend page was created as:

```html id="dmvpys"
<!DOCTYPE html>
<html>
<head>
    <title>Week 6 Docker Mini Project</title>
</head>
<body>
    <h1>Week 6 Day 7</h1>
    <h2>Containerized Application Mini Project</h2>
    <p>Nginx frontend running inside Docker.</p>
    <p>Backend service is available through the internal Docker network.</p>
</body>
</html>
```

---

# Frontend Dockerfile

The frontend Dockerfile was:

```dockerfile id="038k3f"
FROM nginx:alpine

RUN apk add --no-cache curl

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

---

# Why curl Was Installed in the Dockerfile

Earlier in Week 6, `curl` was manually installed in a running container using:

```bash id="3sz8wc"
docker compose exec web apk add --no-cache curl
```

That only modifies the writable layer of that specific container.

If the container is recreated, that installation disappears.

In Day 7:

```dockerfile id="e4aown"
RUN apk add --no-cache curl
```

makes `curl` part of the image.

Therefore:

```text id="f775lm"
Dockerfile
    ↓
build image
    ↓
curl becomes image content
    ↓
every new container has curl
```

This demonstrates the principle:

```text id="x0haib"
Permanent application dependencies
should be defined in the image,
not installed manually after startup.
```

---

# Backend Startup Script

The backend startup script was:

```sh id="c58wvm"
#!/bin/sh

mkdir -p /data

if [ ! -f /data/index.html ]; then
  echo "Week 6 Day 7 backend persistent data" > /data/index.html
fi

python -m http.server 8000 --directory /data
```

The script:

1. Ensures `/data` exists.
2. Creates default application data only when it does not already exist.
3. Starts a Python HTTP server on port `8000`.
4. Serves files from `/data`.

---

# Make Backend Script Executable

```bash id="3fjpee"
chmod +x backend/start.sh
```

---

# Docker Compose Configuration

The final Compose configuration was:

```yaml id="q8u5u7"
services:
  web:
    build: .
    container_name: week6-day7-web
    ports:
      - "8091:80"
    environment:
      BACKEND_HOST: backend
      BACKEND_PORT: "8000"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - week6-day7-network

  backend:
    image: python:3.12-alpine
    container_name: week6-day7-backend
    command: /app/start.sh
    volumes:
      - ./backend/start.sh:/app/start.sh:ro
      - backend-data:/data
    healthcheck:
      test:
        [
          "CMD",
          "python",
          "-c",
          "import urllib.request; urllib.request.urlopen('http://localhost:8000')"
        ]
      interval: 5s
      timeout: 2s
      retries: 5
    networks:
      - week6-day7-network

volumes:
  backend-data:

networks:
  week6-day7-network:
    driver: bridge
```

---

# Validate Compose Configuration

Before starting the stack:

```bash id="xjjbiq"
docker compose config
```

This validates and renders the final Compose configuration.

A useful workflow is:

```text id="0t4nqa"
edit compose.yaml
      ↓
docker compose config
      ↓
validate
      ↓
docker compose up
```

---

# Build and Start the Stack

The application was started with:

```bash id="h2czm8"
docker compose up -d --build
```

`--build` ensures services using:

```yaml id="wf8scl"
build: .
```

have their image rebuilt before startup.

This was important because the frontend image contained:

```dockerfile id="17mgkg"
RUN apk add --no-cache curl
COPY index.html ...
```

---

# When --build Is Needed

Use:

```bash id="297gv3"
docker compose up -d --build
```

when build inputs have changed, including:

```text id="ypgg8l"
Dockerfile
files copied by Dockerfile
application dependencies
RUN instructions
```

A rebuild is generally not necessary for runtime-only changes such as:

```text id="lg8v86"
ports
environment variables
networks
volumes
depends_on
```

---

# Service Status

The Compose stack showed:

```text id="cbt56y"
week6-day7-backend
→ Up
→ healthy

week6-day7-web
→ Up
→ 8091:80
```

The backend health status proved the health check was succeeding.

---

# Frontend Access

The frontend was accessed from the Mac:

```bash id="brwbz2"
curl http://localhost:8091
```

This returned:

```text id="bw1u28"
Week 6 Day 7
Containerized Application Mini Project
```

Traffic path:

```text id="90rtn5"
Mac
 |
 | localhost:8091
 v
host port 8091
 |
 v
web container port 80
 |
 v
Nginx
```

---

# Health Check

The backend health check was:

```yaml id="rcyfqb"
healthcheck:
  test:
    [
      "CMD",
      "python",
      "-c",
      "import urllib.request; urllib.request.urlopen('http://localhost:8000')"
    ]
  interval: 5s
  timeout: 2s
  retries: 5
```

This verifies that the backend application is actually responding over HTTP.

A process being present does not always mean the application is ready.

```text id="02xkhd"
container running
       ≠
application healthy
```

The health check verifies application-level readiness.

---

# depends_on with Health

The frontend configuration used:

```yaml id="zph0s3"
depends_on:
  backend:
    condition: service_healthy
```

This improved on the simpler Day 5 configuration.

Instead of only:

```text id="7pehri"
start backend
     ↓
start web
```

the flow becomes:

```text id="6us57y"
start backend
      ↓
run health checks
      ↓
backend becomes healthy
      ↓
start web
```

---

# Custom Docker Network

Both services joined:

```text id="3dcanv"
week6-day7-network
```

Compose created the project-scoped Docker network:

```text id="iztw2q"
app_week6-day7-network
```

The network driver was:

```text id="r4qw28"
bridge
```

---

# Docker DNS

The frontend resolved the backend service:

```bash id="0k43it"
docker compose exec web \
  getent hosts backend
```

Result:

```text id="aa2ppv"
172.23.0.2 backend backend
```

This demonstrated Docker DNS.

The frontend does not need to know:

```text id="69m7di"
172.23.0.2
```

It simply communicates with:

```text id="0lgr86"
backend
```

---

# Internal Service Communication

The frontend called:

```bash id="h06nxr"
docker compose exec web \
  curl http://backend:8000
```

and successfully reached the backend.

Architecture:

```text id="ymiy24"
web container
     |
     | backend:8000
     v
Docker DNS
     |
     v
backend container
     |
     v
Python HTTP server
```

---

# Environment Variables

The web service contained:

```yaml id="eor5wv"
environment:
  BACKEND_HOST: backend
  BACKEND_PORT: "8000"
```

This allows application configuration to use:

```text id="nme3vu"
BACKEND_HOST=backend
BACKEND_PORT=8000
```

instead of hardcoding a changing container IP.

---

# Bind Mount

The backend script used:

```yaml id="54l0b7"
- ./backend/start.sh:/app/start.sh:ro
```

This is a bind mount.

It maps a host file:

```text id="npndf9"
./backend/start.sh
```

to:

```text id="nxi008"
/app/start.sh
```

inside the container.

The `:ro` option makes it read-only.

---

# Named Volume

Backend persistent data used:

```yaml id="d0y6u5"
- backend-data:/data
```

This is a Docker-managed named volume.

Compose created:

```text id="wzmndb"
app_backend-data
```

---

# Bind Mount vs Named Volume

```text id="wfhba5"
Bind mount:
host file/directory
       ↓
container path

Named volume:
Docker-managed storage
       ↓
container path
```

In this project:

```text id="k4zfao"
backend/start.sh
→ bind mount
→ application startup logic

backend-data
→ named volume
→ persistent application state
```

---

# Existing Volume Reuse

When the Day 7 application first accessed the backend, it returned:

```text id="ly5e60"
Docker Compose persistent data
```

instead of:

```text id="943mlw"
Week 6 Day 7 backend persistent data
```

This happened because:

```text id="tn2w3n"
app_backend-data
```

already existed from Day 5.

Compose reused that volume.

The startup script contained:

```sh id="b9xxst"
if [ ! -f /data/index.html ]; then
```

Because `/data/index.html` already existed, it was not overwritten.

This demonstrated:

```text id="1fk4gt"
new container
      ≠
new application data
```

Persistent state can survive application/container replacement.

---

# Add Persistent Data

An additional line was added:

```bash id="wtmbm2"
docker compose exec backend \
  sh -c 'echo "Persistent line added on Day 7" >> /data/index.html'
```

Verification:

```bash id="b0urdi"
docker compose exec backend \
  cat /data/index.html
```

Result:

```text id="kjooip"
Docker Compose persistent data
Persistent line added on Day 7
```

---

# Remove the Stack

The containers and network were removed:

```bash id="gkqwbl"
docker compose down
```

Compose removed:

```text id="rdu6p8"
week6-day7-web
week6-day7-backend
app_week6-day7-network
```

---

# Volume Survived

The named volume remained:

```bash id="nfj3qh"
docker volume ls | grep backend
```

Result:

```text id="clxowd"
app_backend-data
```

---

# Recreate Stack

The application was recreated:

```bash id="gp5zs1"
docker compose up -d
```

Compose created:

```text id="lnfrxg"
new network
new backend container
new frontend container
```

while reattaching the existing:

```text id="umnmr6"
app_backend-data
```

---

# Verify Persistence

After recreation:

```bash id="hbg0w7"
docker compose exec backend \
  cat /data/index.html
```

still returned:

```text id="7wbvpf"
Docker Compose persistent data
Persistent line added on Day 7
```

This proved persistent storage was independent of the container lifecycle.

---

# Runtime Architecture

The final runtime architecture was:

```text id="2epfgp"
Mac / Browser
      |
      | localhost:8091
      v
+----------------------+
| Nginx Web Container  |
| week6-day7-web       |
+----------------------+
      |
      | backend:8000
      | Docker DNS
      v
+----------------------+
| Python Backend       |
| week6-day7-backend   |
+----------------------+
      |
      | /data
      v
+----------------------+
| app_backend-data     |
| Named Volume         |
+----------------------+
```

Both containers were connected through:

```text id="sbm7xl"
app_week6-day7-network
```

---

# Build Frontend Image

Docker Compose built the frontend image as:

```text id="t1d0tw"
app-web:latest
```

Inspection:

```bash id="603m5a"
docker images | grep app-web
```

Result included:

```text id="po893j"
app-web:latest
59419b8011f4
```

---

# Create ECR Repository

A registry repository was created:

```bash id="tx16nr"
aws ecr create-repository \
  --repository-name week6-day7-web
```

The returned repository URI was:

```text id="73cxu6"
000000000000.dkr.ecr.us-east-1.localhost:5100/week6-day7-web
```

---

# Store Repository URI

```bash id="aktd23"
DAY7_ECR_URI=000000000000.dkr.ecr.us-east-1.localhost:5100/week6-day7-web
```

Verify:

```bash id="r3p9dx"
echo "$DAY7_ECR_URI"
```

---

# Tag Frontend Image

The Compose-built image was tagged:

```bash id="csbtdr"
docker tag \
  app-web:latest \
  "${DAY7_ECR_URI}:v1"
```

The image then had another reference:

```text id="q8xhl9"
000000000000.dkr.ecr.us-east-1.localhost:5100/week6-day7-web:v1
```

Both references pointed to the same image ID:

```text id="a9zqnh"
59419b8011f4
```

---

# Extract Registry Host

```bash id="6f8k5l"
DAY7_REGISTRY_HOST="${DAY7_ECR_URI%%/*}"
```

This produced:

```text id="h06u87"
000000000000.dkr.ecr.us-east-1.localhost:5100
```

---

# Authenticate to Registry

```bash id="5lwd0n"
aws ecr get-login-password \
  | docker login \
      --username AWS \
      --password-stdin \
      "$DAY7_REGISTRY_HOST"
```

Result:

```text id="5d4f1m"
Login Succeeded
```

---

# Push Frontend Image

The image was pushed:

```bash id="9a7t8w"
docker push "${DAY7_ECR_URI}:v1"
```

The registry returned the digest:

```text id="f5tfja"
sha256:59419b8011f47cc72e7e89a4f8b0e50730c82b1dfe72baacdbc1324158aafa79
```

This identified the pushed image artifact.

---

# Registry Layer Reuse

During the push, some layers showed:

```text id="pjp68i"
Mounted from ...
```

instead of:

```text id="efesbu"
Pushed
```

The registry already contained identical content-addressed layers from earlier Week 6 images.

Therefore it reused those layers instead of uploading duplicate data.

Conceptually:

```text id="yljczp"
existing identical layer
         ↓
reuse / mount

new layer
         ↓
upload
```

This improves:

```text id="iu0gqq"
storage efficiency
network efficiency
push speed
```

---

# Verify Registry Catalog

The registry catalog was queried:

```bash id="0rcjae"
curl "http://${DAY7_REGISTRY_HOST}/v2/_catalog"
```

Result:

```json id="hxlxcg"
{
  "repositories": [
    "week6-day7-web",
    "week6-web",
    "week6-webatest"
  ]
}
```

The accidental:

```text id="ffjsg2"
week6-webatest
```

repository originated from the Day 6 zsh variable expansion mistake.

It did not affect the Day 7 repository.

---

# Verify Day 7 Tag

```bash id="qe3pj4"
curl "http://${DAY7_REGISTRY_HOST}/v2/week6-day7-web/tags/list"
```

Result:

```json id="1zllnr"
{
  "name": "week6-day7-web",
  "tags": [
    "v1"
  ]
}
```

This confirmed the Day 7 image was successfully stored in the registry.

---

# Runtime vs Artifact Distribution

The project demonstrated two separate but connected concepts.

## Runtime Architecture

```text id="sfhbvb"
frontend
   ↓
Docker network
   ↓
backend
   ↓
named volume
```

## Artifact Distribution

```text id="bm0ts3"
Dockerfile
   ↓
Docker image
   ↓
tag
   ↓
registry
```

This distinction is important.

Containers are the running workloads.

Images are the artifacts used to create those workloads.

---

# Complete Application Lifecycle

```text id="1be9qr"
Application files
      ↓
Dockerfile
      ↓
docker compose build
      ↓
Docker image
      ↓
docker compose up
      ↓
running containers
      ↓
network + storage
      ↓
application available
```

Then:

```text id="vqpzi3"
built frontend image
      ↓
docker tag
      ↓
docker login
      ↓
docker push
      ↓
container registry
      ↓
image available for deployment elsewhere
```

---

# Day 7 Troubleshooting Lessons

## Existing Volume Data

Unexpected result:

```text id="7xf4ii"
Docker Compose persistent data
```

appeared instead of new Day 7 data.

### Cause

The named volume:

```text id="d7416f"
app_backend-data
```

already existed from Day 5.

### Lesson

Persistent storage can outlive applications and containers.

---

## Container Running vs Healthy

A container being:

```text id="wrkhul"
running
```

does not prove its application is ready.

The health check provided:

```text id="dkkadq"
application-level verification
```

---

## Runtime Installation vs Image Installation

Installing software using:

```bash id="iuodax"
docker compose exec
```

only modifies a running container.

Installing using:

```dockerfile id="39y557"
RUN apk add ...
```

makes the dependency part of the reusable image.

---

# Knowledge Check Summary

## Why install curl in Dockerfile?

So all containers created from the image contain it.

---

## Bind Mount

```text id="yjy9t6"
host file
→ container
```

Used for:

```text id="4u4qmu"
backend/start.sh
```

---

## Named Volume

```text id="gb621u"
Docker-managed persistent storage
```

Used for:

```text id="s2hv01"
/data
```

---

## Health Check

Verifies that the application is actually responding.

---

## depends_on with service_healthy

Waits for the backend health check before starting the dependent frontend service.

---

## Docker DNS

Allows:

```text id="1vmz2w"
backend:8000
```

instead of using a changing container IP.

---

## Persistent Data

The named volume survived:

```text id="mqhtc6"
docker compose down
```

and was reattached after:

```text id="zfxr88"
docker compose up -d
```

---

## docker tag

Creates another image reference.

It does not rebuild the image.

---

## Registry Layer Reuse

Existing identical image layers are reused rather than uploaded again.

---

# Week 6 Final Mental Model

```text id="sn7nqi"
Dockerfile
   ↓
Image
   ↓
Container
```

Multiple containers:

```text id="fp7n6m"
Docker Compose
   ↓
services
networks
volumes
health checks
environment variables
```

Persistent data:

```text id="7o76q4"
container lifecycle
       ≠
volume lifecycle
```

Distribution:

```text id="3fcln8"
local image
   ↓
tag
   ↓
registry
   ↓
pull
   ↓
deployment
```

---

# Week 6 Skills Demonstrated

By completing Week 6, the following Docker skills were demonstrated:

```text id="vbo7fi"
Docker installation/environment         ✅
Images                                  ✅
Containers                              ✅
Container lifecycle                     ✅
docker exec                             ✅
docker inspect                          ✅
Dockerfiles                             ✅
Build context                           ✅
Docker build cache                      ✅
Image tags                              ✅
Image layers                            ✅
Port publishing                         ✅
Bridge networking                       ✅
User-defined networks                   ✅
Docker DNS                              ✅
Container-to-container communication    ✅
Named volumes                           ✅
Bind mounts                             ✅
Read-only mounts                        ✅
Persistent data                         ✅
Docker Compose                          ✅
Multi-service applications              ✅
Environment variables                   ✅
depends_on                              ✅
Health checks                           ✅
Compose networking                      ✅
Compose volumes                         ✅
Container registries                    ✅
AWS ECR concepts                        ✅
Registry authentication                 ✅
Image push/pull                         ✅
Image tags vs digests                   ✅
Registry layer reuse                    ✅
Containerized mini-project              ✅
```

---

# Final Result

Successfully built and deployed a containerized multi-service application with:

```text id="l0j9dw"
Nginx frontend                      ✅
Python backend                      ✅
Custom frontend image               ✅
Docker Compose                      ✅
Custom bridge network               ✅
Docker DNS                          ✅
Internal service communication      ✅
Environment variables               ✅
Backend health check                ✅
Health-aware dependency             ✅
Bind-mounted startup script         ✅
Named persistent volume             ✅
Container recreation                ✅
Persistent data recovery            ✅
ECR repository                      ✅
Registry authentication             ✅
Frontend image tagging              ✅
Registry push                       ✅
Registry API verification           ✅
Image layer reuse                   ✅
```

**Week 6 — Docker Fundamentals completed successfully.**