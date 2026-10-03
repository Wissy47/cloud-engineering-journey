# Week 6 Day 4 — Docker Storage and Persistence

## Objective

Understand how Docker stores data and how to keep application data persistent across container restarts, replacement, and deletion.

Topics covered:

- Container writable layer
- Named volumes
- Bind mounts
- Persistent storage
- Shared storage between containers
- Read-only mounts
- Volume inspection
- Storage lifecycle
- Storage troubleshooting

---

# Why Docker Storage Matters

By default, containers have a writable layer.

If data is stored only inside that writable layer:

```text
Container
   |
   v
Writable Layer
   |
   v
Data
```

the data is tied to that specific container.

If the container is removed:

```text
Container removed
      |
      v
Writable layer removed
      |
      v
Data removed
```

This is why persistent applications need storage that exists independently of the container lifecycle.

---

# Container Writable Layer

A temporary Ubuntu container was created:

```bash
docker run -it \
  --name week6-storage-test \
  ubuntu:24.04 \
  bash
```

Inside the container:

```bash
mkdir -p /data
echo "temporary container data" > /data/test.txt
cat /data/test.txt
```

The container was exited:

```bash
exit
```

Then restarted:

```bash
docker start week6-storage-test
```

The file still existed:

```bash
docker exec week6-storage-test \
  cat /data/test.txt
```

This showed:

```text
stop/start same container
        |
        v
writable layer remains
```

---

# Removing the Container

The container was removed:

```bash
docker stop week6-storage-test
docker rm week6-storage-test
```

A new container was created:

```bash
docker run -d \
  --name week6-storage-test \
  ubuntu:24.04 \
  sleep infinity
```

The original file was no longer available:

```bash
docker exec week6-storage-test \
  cat /data/test.txt
```

This demonstrated:

```text
container removed
        |
        v
writable layer removed
        |
        v
data lost
```

---

# Named Volumes

A persistent Docker volume was created:

```bash
docker volume create week6-data
```

Volumes were listed:

```bash
docker volume ls
```

The volume was inspected:

```bash
docker volume inspect week6-data
```

A named volume exists independently of containers.

Conceptually:

```text
week6-data
    |
    +---- Container A
    |
    +---- Container B
```

---

# Mount Named Volume

A container was created with the volume mounted:

```bash
docker run -d \
  --name week6-volume-a \
  -v week6-data:/data \
  ubuntu:24.04 \
  sleep infinity
```

Mount syntax:

```text
-v week6-data:/data
```

means:

```text
week6-data = Docker named volume
/data      = mount point inside container
```

---

# Write Persistent Data

Data was written into the mounted volume:

```bash
docker exec week6-volume-a \
  sh -c 'echo "Persistent Docker volume data" > /data/persistent.txt'
```

Verification:

```bash
docker exec week6-volume-a \
  cat /data/persistent.txt
```

Result:

```text
Persistent Docker volume data
```

---

# Delete Container but Keep Data

The container was removed:

```bash
docker rm -f week6-volume-a
```

The volume still existed:

```bash
docker volume ls | grep week6-data
```

This demonstrated:

```text
Container removed
      |
      v
Volume remains
```

---

# Create Replacement Container

A new container was created using the same volume:

```bash
docker run -d \
  --name week6-volume-b \
  -v week6-data:/data \
  ubuntu:24.04 \
  sleep infinity
```

The data was still present:

```bash
docker exec week6-volume-b \
  cat /data/persistent.txt
```

Result:

```text
Persistent Docker volume data
```

This proved persistence across container replacement.

---

# Persistent Storage Model

```text
Container A
    |
    | writes
    v
week6-data
    |
Container A deleted
    |
Container B created
    |
    v
same week6-data
    |
    v
original data remains
```

This is one of the most important Docker storage concepts.

---

# Shared Volume Between Containers

A second container was created:

```bash
docker run -d \
  --name week6-volume-c \
  -v week6-data:/data \
  ubuntu:24.04 \
  sleep infinity
```

Both containers mounted the same volume.

Architecture:

```text
week6-volume-b
       |
       v
   week6-data
       ^
       |
week6-volume-c
```

---

# Write from Container B

```bash
docker exec week6-volume-b \
  sh -c 'echo "Written by container B" >> /data/persistent.txt'
```

Container C read the update:

```bash
docker exec week6-volume-c \
  cat /data/persistent.txt
```

Result:

```text
Persistent Docker volume data
Written by container B
```

---

# Write from Container C

```bash
docker exec week6-volume-c \
  sh -c 'echo "Written by container C" >> /data/persistent.txt'
```

Container B read the file again:

```bash
docker exec week6-volume-b \
  cat /data/persistent.txt
```

Result:

```text
Persistent Docker volume data
Written by container B
Written by container C
```

This proved that multiple containers can share the same volume.

---

# Inspect Named Volume Mount

Mount information was inspected:

```bash
docker inspect week6-volume-b \
  --format '{{json .Mounts}}'
```

Formatted view:

```bash
docker inspect week6-volume-b \
  --format '{{range .Mounts}}Type={{.Type}} Name={{.Name}} Source={{.Source}} Destination={{.Destination}}{{println}}{{end}}'
```

Result:

```text
Type=volume
Name=week6-data
Source=/var/lib/docker/volumes/week6-data/_data
Destination=/data
```

Interpretation:

```text
Type
→ Docker volume

Name
→ volume name

Source
→ Docker-managed storage location

Destination
→ path inside container
```

---

# Docker Desktop Storage Location

On Docker Desktop for macOS:

```text
/var/lib/docker/volumes/...
```

exists inside Docker Desktop's Linux environment.

It is not a normal macOS directory intended for direct manual management.

Docker should manage the volume location.

---

# Bind Mounts

A bind mount uses a directory chosen directly from the host filesystem.

A Mac directory was created:

```bash
mkdir -p ~/week6-bind-data
```

A file was created on the Mac:

```bash
echo "Created on my Mac" \
  > ~/week6-bind-data/host.txt
```

---

# Mount Host Directory

A container was created:

```bash
docker run -d \
  --name week6-bind \
  -v ~/week6-bind-data:/data \
  ubuntu:24.04 \
  sleep infinity
```

Mount relationship:

```text
Mac:
~/week6-bind-data
        |
        v
Container:
/data
```

---

# Host to Container Sharing

The Mac-created file was read from the container:

```bash
docker exec week6-bind \
  cat /data/host.txt
```

Result:

```text
Created on my Mac
```

---

# Container to Host Sharing

A file was created from inside the container:

```bash
docker exec week6-bind \
  sh -c 'echo "Created inside container" > /data/container.txt'
```

The Mac could immediately read it:

```bash
cat ~/week6-bind-data/container.txt
```

Result:

```text
Created inside container
```

This demonstrated two-way filesystem sharing.

---

# Bind Mount Model

```text
Mac filesystem
~/week6-bind-data
        |
        | bind mount
        v
Container
/data
```

Both sides are viewing the same underlying host directory.

---

# Named Volume vs Bind Mount

## Named Volume

```text
Docker manages storage location
```

Useful for:

```text
database data
application state
persistent service data
```

---

## Bind Mount

```text
host manages exact storage path
```

Useful for:

```text
source code
development files
configuration files
local editing
```

---

# Comparison

```text
Named Volume
--------------------------------
Docker-managed
Persistent
Reusable
Good for application state
Independent of container lifecycle


Bind Mount
--------------------------------
Host-managed
Uses exact host path
Persistent
Good for development
Easy host/container file sharing
```

---

# Read-Only Bind Mount

A read-only mount was tested:

```bash
docker run --rm \
  -v ~/week6-bind-data:/data:ro \
  ubuntu:24.04 \
  cat /data/host.txt
```

Reading worked:

```text
Created on my Mac
```

---

# Write Attempt on Read-Only Mount

A write was attempted:

```bash
docker run --rm \
  -v ~/week6-bind-data:/data:ro \
  ubuntu:24.04 \
  sh -c 'echo test > /data/test.txt'
```

Result:

```text
Read-only file system
```

The suffix:

```text
:ro
```

means:

```text
read-only
```

---

# Inspect Bind Mount

The bind mount was inspected:

```bash
docker inspect week6-bind \
  --format '{{range .Mounts}}Type={{.Type}} Source={{.Source}} Destination={{.Destination}} RW={{.RW}}{{println}}{{end}}'
```

Result:

```text
Type=bind
Source=/Users/wissy47/week6-bind-data
Destination=/data
RW=true
```

Interpretation:

```text
Type=bind
→ host filesystem directory

Source
→ path on Mac

Destination
→ path inside container

RW=true
→ read/write access
```

---

# Storage Lifecycle

The key idea from Day 4:

```text
Container lifecycle
        ≠
Data lifecycle
```

Containers should be disposable.

Persistent application data should exist outside the container's writable layer.

---

# Cloud Comparison

This concept connects directly to previous AWS storage work.

```text
EC2 + EBS
→ persistent block storage

EC2 + EFS
→ persistent/shared filesystem

Container + Docker Volume
→ persistent container storage
```

The broader architecture principle is:

```text
compute can be replaced
while
data remains persistent
```

---

# Database Example

A database container should not rely only on its writable layer.

Bad model:

```text
Database container
        |
        v
container writable layer
```

If deleted:

```text
database container deleted
        |
        v
database data lost
```

Better model:

```text
Database container
        |
        v
Named Volume
        |
        v
Persistent database files
```

Now:

```text
old database container deleted
        |
        v
new database container
        |
        v
same named volume
        |
        v
data survives
```

---

# Storage Troubleshooting

## List Volumes

```bash
docker volume ls
```

---

## Inspect Volume

```bash
docker volume inspect week6-data
```

---

## Inspect Container Mounts

```bash
docker inspect CONTAINER \
  --format '{{json .Mounts}}'
```

---

## Check Mounted Files

```bash
docker exec CONTAINER \
  ls -lah /data
```

---

## Check Volume Data

```bash
docker exec CONTAINER \
  cat /data/persistent.txt
```

---

# Knowledge Check Summary

## Writable Layer

Container-specific storage.

Data disappears when the container is removed.

---

## Named Volume

Docker-managed persistent storage.

Can survive container replacement.

---

## Bind Mount

Maps a specific host directory into a container.

---

## Mount Syntax

Named volume:

```text
-v VOLUME_NAME:CONTAINER_PATH
```

Example:

```text
-v week6-data:/data
```

Bind mount:

```text
-v HOST_PATH:CONTAINER_PATH
```

Example:

```text
-v ~/week6-bind-data:/data
```

---

## Read-Only Mount

```text
:ro
```

prevents writes.

---

## Shared Volumes

Multiple containers can mount the same named volume.

---

# Day 4 Mental Model

```text
Writable Layer
→ tied to container

Named Volume
→ persistent Docker-managed storage

Bind Mount
→ persistent host-managed storage

:ro
→ read-only
```

And most importantly:

```text
Containers should be replaceable.

Persistent data should not depend
on the lifecycle of one container.
```

---

# Final Result

Successfully demonstrated:

```text
Container writable layer          ✅
Data survives stop/start          ✅
Data lost after container delete  ✅
Named volume creation             ✅
Persistent volume data            ✅
Container replacement             ✅
Shared volume between containers  ✅
Volume inspection                 ✅
Bind mount                        ✅
Host → container sharing          ✅
Container → host sharing          ✅
Read-only mounts                  ✅
Storage troubleshooting           ✅
Persistence concepts              ✅
```