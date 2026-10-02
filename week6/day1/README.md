# Week 6 Day 1 — Containers and Docker Fundamentals

## Objective

Understand the core concepts behind containers and Docker, including:

- Containers vs virtual machines
- Docker images vs containers
- Docker architecture
- Container lifecycle
- Main process behavior
- Container isolation
- Namespaces
- cgroups
- Basic troubleshooting
- Container cleanup

---

# Why Containers?

Applications often behave differently across environments because of differences in:

```text
Operating system
Runtime versions
Libraries
Dependencies
Configuration
```

Containers help solve this by packaging an application together with the environment it needs.

Conceptually:

```text
Application
+
Runtime
+
Libraries
+
Configuration
        |
        v
      Image
        |
        v
    Container
```

This makes deployments more repeatable.

---

# Virtual Machine vs Container

## Virtual Machine

A virtual machine normally includes its own guest operating system.

```text
Physical Host
      |
      v
Hypervisor
   /       \
 VM A      VM B
  |          |
Guest OS   Guest OS
  |          |
 App        App
```

---

## Container

Containers share the underlying host kernel.

```text
Host Machine
      |
      v
Host Kernel
      |
      v
Container Runtime
   /       |       \
  C1       C2       C3
 App      App      App
```

Containers are generally lighter than full virtual machines because they do not require a complete guest operating system for every workload.

---

# Docker Image vs Container

A Docker image is a reusable template.

A container is an instance created from that image.

```text
ubuntu:24.04 image
        |
        +---- Container A
        |
        +---- Container B
        |
        +---- Container C
```

One image can create many containers.

---

# Docker Architecture

Docker uses a client/server architecture.

```text
User
 |
 v
Docker CLI
 |
 v
Docker API
 |
 v
Docker Daemon
 |
 +---- Images
 +---- Containers
 +---- Networks
 +---- Volumes
```

Example command:

```bash
docker run ubuntu:24.04
```

Conceptually:

```text
Docker CLI
    |
    v
Docker daemon
    |
    v
Check for image
    |
    +---- image exists locally
    |
    +---- or pull image
    |
    v
Create container
    |
    v
Start container
```

---

# Inspect Docker Environment

Docker installation was inspected using:

```bash
docker version
```

and:

```bash
docker info
```

Useful information includes:

```text
Docker Server Version
Architecture
Operating System
Images
Running containers
Stopped containers
```

---

# Running Containers

Running containers were inspected with:

```bash
docker ps
```

All containers, including stopped containers, were inspected with:

```bash
docker ps -a
```

Important distinction:

```text
docker ps
→ running containers only

docker ps -a
→ running + stopped + created containers
```

---

# Inspect Docker Images

Images were inspected with:

```bash
docker images
```

An image can exist without any running container.

```text
Image
 |
 +---- zero containers
 |
 +---- one container
 |
 +---- many containers
```

---

# Hello World Container

The first test container was launched with:

```bash
docker run hello-world
```

The container completed its process and exited.

It appeared in:

```bash
docker ps -a
```

but not in:

```bash
docker ps
```

This demonstrated an important rule:

```text
Container lifetime
      =
lifetime of its main process
```

When the main process exits, the container stops.

---

# Interactive Ubuntu Container

An Ubuntu container was launched:

```bash
docker run \
  --name week6-ubuntu \
  -it \
  ubuntu:24.04 \
  bash
```

Command breakdown:

```text
docker run
→ create and start container

--name week6-ubuntu
→ assign container name

-i
→ interactive input

-t
→ allocate terminal

ubuntu:24.04
→ source image

bash
→ main process
```

Inside the container:

```bash
cat /etc/os-release
```

```bash
hostname
```

```bash
ps aux
```

The container contained significantly fewer processes than a full Ubuntu virtual machine.

---

# Creating Data Inside a Container

Inside `week6-ubuntu`:

```bash
mkdir -p /opt/week6
```

```bash
echo "Week 6 Docker Fundamentals" \
  > /opt/week6/day1.txt
```

Verification:

```bash
cat /opt/week6/day1.txt
```

Result:

```text
Week 6 Docker Fundamentals
```

---

# Container Stops When Main Process Exits

The container was running:

```text
PID 1
 |
 v
bash
```

When:

```bash
exit
```

was executed, Bash ended.

Therefore:

```text
bash exits
    |
    v
PID 1 exits
    |
    v
container stops
```

---

# Restarting the Same Container

The container was restarted:

```bash
docker start week6-ubuntu
```

Then accessed using:

```bash
docker exec -it week6-ubuntu bash
```

The previously created file was still present:

```bash
cat /opt/week6/day1.txt
```

Result:

```text
Week 6 Docker Fundamentals
```

This showed that restarting the same container retains changes in its writable container layer.

---

# Creating a New Container

A second container was created from the same image:

```bash
docker run \
  --name week6-ubuntu-new \
  -it \
  ubuntu:24.04 \
  bash
```

Inside it:

```bash
cat /opt/week6/day1.txt
```

The file did not exist.

Architecture:

```text
ubuntu:24.04
      |
      +---- week6-ubuntu
      |       |
      |       +---- day1.txt
      |
      +---- week6-ubuntu-new
              |
              +---- no day1.txt
```

Changes made inside one container do not modify the original image or other containers.

---

# Container Lifecycle

The main container lifecycle is:

```text
Image
  |
  v
create
  |
  v
Created Container
  |
  v
start
  |
  v
Running Container
  |
  v
stop
  |
  v
Stopped Container
  |
  v
start again
```

Eventually:

```text
Stopped Container
       |
       v
      rm
       |
       v
Container removed
```

---

# docker run vs docker start

Important distinction:

```text
docker run
=
docker create
+
docker start
```

`docker run` creates a new container.

`docker start` starts an existing container.

---

# Inspecting a Container

The Ubuntu container was inspected:

```bash
docker inspect week6-ubuntu \
  --format \
  'Name={{.Name}} Status={{.State.Status}} PID={{.State.Pid}} Image={{.Config.Image}}'
```

Result:

```text
Name=/week6-ubuntu
Status=running
PID=66103
Image=ubuntu:24.04
```

This confirmed the container was running and showed its host-visible process ID.

---

# Inspecting Container Processes

Processes were inspected with:

```bash
docker top week6-ubuntu
```

Result included:

```text
CMD
bash
```

The main process was Bash.

Conceptually:

```text
week6-ubuntu
      |
      v
PID 1: bash
```

---

# docker exec

Commands can be executed inside a running container without opening a separate interactive terminal.

Examples:

```bash
docker exec week6-ubuntu hostname
```

```bash
docker exec week6-ubuntu \
  cat /opt/week6/day1.txt
```

Interactive shell:

```bash
docker exec -it week6-ubuntu bash
```

---

# docker stop

A container can be stopped:

```bash
docker stop week6-ubuntu
```

After stopping:

```bash
docker ps
```

does not show it.

However:

```bash
docker ps -a
```

still shows the container.

Therefore:

```text
stop
≠
delete
```

---

# docker restart

A running or stopped container can be restarted:

```bash
docker restart week6-ubuntu
```

Conceptually:

```text
stop
 |
 v
start
```

for the same container.

---

# Container Logs

Container logs can be inspected using:

```bash
docker logs CONTAINER
```

Live logs:

```bash
docker logs -f CONTAINER
```

Useful for troubleshooting applications such as:

```text
Nginx
Node.js
Python
Laravel
databases
```

`Ctrl+C` stops following the logs without stopping the container.

---

# Create Without Starting

A container was created without starting it:

```bash
docker create \
  --name week6-created \
  ubuntu:24.04 \
  sleep infinity
```

The container appeared as:

```text
Created
```

when running:

```bash
docker ps -a
```

This demonstrated:

```text
docker create
→ create only

docker run
→ create + start
```

---

# Main Process with sleep infinity

The container used:

```text
sleep infinity
```

as its main process.

Conceptually:

```text
PID 1
 |
 v
sleep infinity
 |
 v
process remains alive
 |
 v
container remains running
```

This technique is useful in labs when a container needs to remain alive.

---

# Container Isolation

Containers are processes running on the same host but isolated from one another.

Isolation includes different views of:

```text
processes
networking
hostname
filesystem
mounts
```

Conceptually:

```text
Host
 |
 +---- Container A
 |       |
 |       +---- isolated process view
 |       +---- isolated hostname
 |       +---- isolated network
 |
 +---- Container B
         |
         +---- isolated process view
         +---- isolated hostname
         +---- isolated network
```

---

# Namespaces

Linux namespaces provide isolation.

A useful way to remember this:

```text
Namespaces
=
what a container can see
```

Examples include isolation of:

```text
process IDs
hostname
network interfaces
mount points
```

---

# cgroups

Control groups manage resource usage.

Useful memory rule:

```text
Namespaces
→ isolation

cgroups
→ resource control
```

Examples of resources controlled through cgroups include:

```text
CPU
memory
I/O
process counts
```

---

# Resource-Limited Container

A container can be started with resource restrictions:

```bash
docker run --rm \
  --memory 256m \
  --cpus 0.5 \
  ubuntu:24.04 \
  echo "resource-limited container"
```

Configuration:

```text
Memory:
256 MB

CPU:
0.5 CPU
```

---

# --rm Flag

The `--rm` flag automatically removes a container after its process exits.

```text
docker run --rm
       |
       v
container starts
       |
       v
process completes
       |
       v
container automatically removed
```

This is useful for temporary containers.

---

# Removing Containers

Stop:

```bash
docker stop week6-created
```

Remove:

```bash
docker rm week6-created
```

Important distinction:

```text
docker stop
→ stop but retain container

docker rm
→ delete container object
```

Images are removed separately using:

```bash
docker rmi IMAGE
```

---

# Basic Docker Troubleshooting Workflow

When a container is not working:

```text
Problem
   |
   v
docker ps -a
   |
   v
docker logs
   |
   v
docker inspect
   |
   v
docker top
   |
   v
docker exec
```

---

## Check Container Status

```bash
docker inspect CONTAINER \
  --format '{{.State.Status}}'
```

---

## Check Exit Code

```bash
docker inspect CONTAINER \
  --format '{{.State.ExitCode}}'
```

Exit code:

```text
0
→ successful process completion

non-zero
→ process encountered an error or unsuccessful condition
```

---

## Check Processes

```bash
docker top CONTAINER
```

---

## Enter Container

```bash
docker exec -it CONTAINER bash
```

If Bash does not exist:

```bash
docker exec -it CONTAINER sh
```

---

# Knowledge Check

## 1. Image vs Container

An image is the reusable template used to create containers.

A container is an instance created from an image.

---

## 2. docker run vs docker start

```text
docker run
→ create + start new container

docker start
→ start an existing container
```

---

## 3. Why hello-world stopped

Its main process completed successfully.

Therefore the container stopped.

---

## 4. PID 1

When PID 1 exits:

```text
container stops
```

---

## 5. docker stop vs docker rm

```text
docker stop
→ stops container

docker rm
→ removes container object
```

---

## 6. docker exec

Runs a command inside an existing running container.

---

## 7. --rm

Automatically removes a container when its main process finishes.

---

## 8. Namespaces

Namespaces provide isolation.

```text
Namespaces
→ what the container can see
```

---

## 9. cgroups

cgroups control resource usage.

```text
cgroups
→ how much the container can use
```

---

## 10. Container Filesystem Isolation

Files created inside one container belong to that container's writable layer.

They do not automatically modify:

```text
the source image
other containers
```

---

# Command Summary

```bash
docker version
docker info

docker images

docker ps
docker ps -a

docker run
docker create
docker start
docker stop
docker restart

docker exec
docker logs
docker inspect
docker top

docker rm
docker rmi
```

---

# Key Concepts

```text
Image      = reusable blueprint

Container  = instance created from image

PID 1 exits
           =
container stops

Namespaces = isolation

cgroups    = resource control

docker run = create + start

docker stop
           =
stop but keep

docker rm  = remove container
```

---

# Final Result

Successfully demonstrated:

```text
Docker environment inspection       ✅
Image vs container                  ✅
hello-world lifecycle               ✅
Interactive Ubuntu container        ✅
Main process behavior               ✅
Container writable layer            ✅
Container restart                   ✅
New-container isolation             ✅
docker inspect                      ✅
docker top                          ✅
docker exec                         ✅
docker create                       ✅
docker start / stop / restart       ✅
Namespaces concept                  ✅
cgroups concept                     ✅
Resource limits                     ✅
Basic troubleshooting               ✅
Container cleanup                   ✅
```
