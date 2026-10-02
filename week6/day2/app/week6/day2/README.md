# Week 6 Day 2 — Building Docker Images with Dockerfiles

## Objective

Learn how to build custom Docker images using a `Dockerfile`, understand image layers and caching, version images with tags, and replace running containers with newer image versions.

Topics covered:

- Dockerfiles
- Base images
- Build context
- `FROM`
- `COPY`
- `RUN`
- `CMD`
- `EXPOSE`
- Image tags
- Image layers
- Build cache
- Cache invalidation
- `.dockerignore`
- Port publishing
- Container replacement
- Image troubleshooting

---

# Docker Build Workflow

The main workflow is:

```text
Application files
      +
Dockerfile
      |
      v
docker build
      |
      v
Docker Image
      |
      v
docker run
      |
      v
Container
```

Day 1 focused on:

```text
Image → Container
```

Day 2 introduced:

```text
Dockerfile → Image → Container
```

---

# Project Structure

The project directory was created:

```bash
mkdir -p week6/day2/app
cd week6/day2/app
```

The working directory contained:

```text
week6/day2/app/
├── Dockerfile
└── index.html
```

---

# Create Web Application

A simple HTML application was created:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Week 6 Docker Lab</title>
</head>
<body>
    <h1>Week 6 Day 2</h1>
    <h2>My First Custom Docker Image</h2>
    <p>This page is running from a Docker container.</p>
</body>
</html>
```

---

# First Dockerfile

The Dockerfile was:

```dockerfile
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

---

# FROM

```dockerfile
FROM nginx:alpine
```

defines the base image.

Conceptually:

```text
nginx:alpine
     |
     v
our custom image
```

The custom image inherits the files and configuration provided by the base image.

This includes Nginx itself and its startup configuration.

---

# COPY

```dockerfile
COPY index.html /usr/share/nginx/html/index.html
```

copies a file from the Docker build context into the image.

Conceptually:

```text
Local machine:

index.html

      |
      v

Docker image:

/usr/share/nginx/html/index.html
```

---

# EXPOSE

```dockerfile
EXPOSE 80
```

documents that the application expects to listen on container port 80.

Important:

```text
EXPOSE 80
≠
publish port to host
```

Port publishing happens with:

```bash
docker run -p HOST:CONTAINER
```

---

# Build Context

The image was built using:

```bash
docker build -t week6-day2-web:v1 .
```

The final:

```text
.
```

means:

```text
use current directory as build context
```

The build context contains files Docker may reference during the build.

Example:

```text
.
├── Dockerfile
├── index.html
└── .dockerignore
```

---

# Build First Image

The first custom image was built:

```bash
docker build -t week6-day2-web:v1 .
```

Command breakdown:

```text
docker build
→ build image

-t
→ assign image name/tag

week6-day2-web
→ image name

:v1
→ image version tag

.
→ build context
```

---

# Inspect Images

Images were inspected with:

```bash
docker images | grep week6-day2
```

Initial result included:

```text
week6-day2-web:v1
```

---

# Run Custom Image

The first attempt used:

```bash
docker run -d \
  --name week6-day2-web \
  -p 8080:80 \
  week6-day2-web:v1
```

Docker returned:

```text
Bind for 127.0.0.1:8080 failed:
port is already allocated
```

Ports `8080` and `8081` were already in use.

The application was therefore published using:

```bash
docker run -d \
  --name week6-day2-web \
  -p 8088:80 \
  week6-day2-web:v1
```

---

# Port Mapping

```text
-p 8088:80
```

means:

```text
HOST : CONTAINER

8088 : 80
```

Architecture:

```text
Mac localhost:8088
        |
        v
Docker port publishing
        |
        v
Container port 80
        |
        v
Nginx
```

---

# Test Application

The application was tested:

```bash
curl http://localhost:8088
```

The response showed:

```text
Week 6 Day 2
My First Custom Docker Image
```

This confirmed:

```text
Docker image
      |
      v
Container
      |
      v
Nginx
      |
      v
index.html
```

---

# Inspect Running Container

Useful commands included:

```bash
docker ps
```

```bash
docker inspect week6-day2-web \
  --format 'Image={{.Config.Image}} Status={{.State.Status}}'
```

```bash
docker top week6-day2-web
```

```bash
docker logs week6-day2-web
```

---

# Nginx Logs

Repeated requests were generated:

```bash
curl http://localhost:8088
curl http://localhost:8088
curl http://localhost:8088
```

Logs were inspected:

```bash
docker logs week6-day2-web
```

This demonstrated how application requests appear in container logs.

---

# Docker Image Layers

Image history was inspected:

```bash
docker history week6-day2-web:v1
```

The output showed custom layers:

```text
EXPOSE [80/tcp]
COPY index.html ...
```

and many existing layers inherited from:

```text
nginx:alpine
```

Conceptually:

```text
Alpine base
     |
     v
Nginx packages
     |
     v
Nginx configuration
     |
     v
COPY index.html
     |
     v
EXPOSE 80
     |
     v
week6-day2-web:v1
```

---

# Inherited CMD

The image history showed:

```text
CMD ["nginx" "-g" "daemon off;"]
```

This command came from the `nginx:alpine` base image.

The custom Dockerfile did not need to define a new `CMD`.

This demonstrated that base images can provide configuration such as:

```text
CMD
ENTRYPOINT
ENV
EXPOSE
WORKDIR
```

---

# RUN vs CMD

Important distinction:

```text
RUN
=
execute during image build
```

Example:

```dockerfile
RUN apk add curl
```

Flow:

```text
docker build
      |
      v
RUN executes
      |
      v
result stored in image
```

---

```text
CMD
=
default command when container starts
```

Example:

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

Flow:

```text
docker run
      |
      v
container starts
      |
      v
CMD executes
```

Memory rule:

```text
RUN = build time
CMD = runtime
```

---

# Build Cache

Building the same image again allows Docker to reuse unchanged work.

Example:

```bash
docker build -t week6-day2-web:v1 .
```

Docker can display:

```text
CACHED
```

for unchanged steps.

---

# Modify Application

The HTML application was changed to:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Week 6 Docker Lab</title>
</head>
<body>
    <h1>Week 6 Day 2</h1>
    <h2>Docker Image Version 2</h2>
    <p>I changed the application and rebuilt the image.</p>
</body>
</html>
```

---

# Build Version 2

A new image was built:

```bash
docker build -t week6-day2-web:v2 .
```

The output included:

```text
CACHED [1/2] FROM nginx:alpine
[2/2] COPY index.html ...
```

This demonstrated cache behavior.

The base image was unchanged:

```text
FROM nginx:alpine
→ cached
```

The application changed:

```text
index.html changed
        |
        v
COPY cache invalidated
        |
        v
COPY rebuilt
```

---

# Image Versions

Images were inspected:

```bash
docker images | grep week6-day2
```

Result:

```text
week6-day2-web:v1
week6-day2-web:v2
```

Image versions can coexist.

---

# Running Container Does Not Automatically Update

After building `v2`, the existing container still returned:

```text
My First Custom Docker Image
```

because it was created from:

```text
week6-day2-web:v1
```

This demonstrated:

```text
building a new image
        ≠
modifying a running container
```

---

# Replace Container with New Version

The old container was stopped:

```bash
docker stop week6-day2-web
```

Then removed:

```bash
docker rm week6-day2-web
```

A new container was created from `v2`:

```bash
docker run -d \
  --name week6-day2-web \
  -p 8088:80 \
  week6-day2-web:v2
```

Testing:

```bash
curl http://localhost:8088
```

returned:

```text
Docker Image Version 2
```

---

# Deployment Pattern

The lab demonstrated:

```text
change application
       |
       v
build new image
       |
       v
tag new image version
       |
       v
stop old container
       |
       v
remove old container
       |
       v
start new container
       |
       v
new version is live
```

---

# Image Tags

A new tag can be created:

```bash
docker tag \
  week6-day2-web:v2 \
  week6-day2-web:latest
```

Conceptually:

```text
v2 ───────┐
          |
latest ───┴──> same image
```

A tag is a human-readable reference to an image.

---

# .dockerignore

A `.dockerignore` file was introduced:

```text
.git
.gitignore
*.log
.DS_Store
tmp
```

Its purpose is to prevent unnecessary files from being included in the build context.

Benefits include:

```text
smaller build context
faster builds
better cache behavior
reduced accidental file exposure
```

---

# Image Inspection

Image metadata can be inspected:

```bash
docker image inspect week6-day2-web:v2
```

A formatted example:

```bash
docker image inspect week6-day2-web:v2 \
  --format 'Image={{.Id}} Cmd={{json .Config.Cmd}} ExposedPorts={{json .Config.ExposedPorts}}'
```

---

# Image Troubleshooting

## Build Without Cache

```bash
docker build \
  --no-cache \
  -t week6-day2-web:v2 \
  .
```

This forces Docker to rebuild every applicable step.

---

## Verbose Build Output

```bash
docker build \
  --progress=plain \
  -t week6-day2-web:v2 \
  .
```

---

## Inspect History

```bash
docker history week6-day2-web:v2
```

---

## Enter Image Interactively

```bash
docker run \
  --rm \
  -it \
  week6-day2-web:v2 \
  sh
```

Inside the container:

```bash
ls -lah /usr/share/nginx/html
```

```bash
cat /usr/share/nginx/html/index.html
```

This helps verify that expected application files were actually included in the image.

---

# Port Conflict Troubleshooting

The lab encountered:

```text
port is already allocated
```

Useful checks include:

```bash
docker ps \
  --format 'table {{.Names}}\t{{.Ports}}'
```

```bash
docker ps \
  --format '{{.Names}}\t{{.Ports}}' \
  | grep 8080
```

On macOS:

```bash
lsof -nP \
  -iTCP:8080 \
  -sTCP:LISTEN
```

Solutions include:

```text
stop the process using the port
```

or:

```text
choose another available host port
```

The lab successfully used:

```text
8088
```

---

# Knowledge Check Summary

## Dockerfile

Defines instructions for building a Docker image.

---

## FROM

Defines the base image.

```dockerfile
FROM nginx:alpine
```

---

## COPY

Copies files from the build context into the image.

---

## RUN

Executes commands during image build.

---

## CMD

Defines the default command executed when the container starts.

---

## EXPOSE

Documents the intended container port.

It does not publish that port to the host.

---

## Build Context

The final `.` in:

```bash
docker build -t week6-day2-web:v2 .
```

means:

```text
use current directory as build context
```

---

## Docker Cache

Unchanged layers can be reused.

Changed files invalidate affected layers.

---

## Image Versioning

Building `v2` does not modify containers already running `v1`.

A new container must be created from the new image.

---

## Tags

Tags are human-friendly references to images.

---

## Port Publishing

```text
-p HOST:CONTAINER
```

Example:

```text
-p 8088:80
```

means:

```text
host port 8088
      |
      v
container port 80
```

---

# Day 2 Mental Model

```text
Dockerfile
    |
    v
docker build
    |
    v
Image
    |
    v
docker run
    |
    v
Container
```

Dockerfile instructions:

```text
FROM
→ base image

COPY
→ copy files into image

RUN
→ build-time command

CMD
→ runtime command

EXPOSE
→ document intended container port
```

---

# Final Result

Successfully demonstrated:

```text
Create Dockerfile                  ✅
Use base image                     ✅
Copy application into image        ✅
Build custom image                 ✅
Tag image v1                       ✅
Run custom image                   ✅
Publish container port             ✅
Troubleshoot port conflict         ✅
Inspect image layers               ✅
Understand inherited CMD           ✅
Build cache                         ✅
Cache invalidation                  ✅
Create image v2                    ✅
Run multiple image versions        ✅
Replace old container               ✅
Deploy v2                           ✅
Image tagging                       ✅
.dockerignore concept               ✅
Image troubleshooting               ✅
```
