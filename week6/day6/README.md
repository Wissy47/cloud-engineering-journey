# Week 6 Day 6 — Container Registries and AWS ECR

## Objective

Learn how container registries are used to distribute Docker images between systems and understand the complete image lifecycle:

```text
build
  ↓
tag
  ↓
authenticate
  ↓
push
  ↓
registry
  ↓
pull
  ↓
run elsewhere
```

Topics covered:

- Container registries
- Registry vs repository
- Image tags
- Image digests
- AWS ECR
- ECR authentication
- Docker tagging
- Docker push
- Docker pull
- OCI registry API
- Registry repositories
- Registry tags
- Layer reuse
- Content-addressable storage
- Floci ECR behavior
- Shell variable expansion with zsh

---

# Why Container Registries?

Docker images created locally only exist on the machine where they were built.

For example:

```text
Mac
└── week6-day2-web:v2
```

Another server cannot automatically run that image.

A container registry solves this problem.

```text
Developer machine
      ↓
docker build
      ↓
local image
      ↓
docker push
      ↓
Container Registry
      ↓
docker pull
      ↓
Server / ECS / Kubernetes / another developer
```

A registry allows container images to be stored centrally and distributed to other environments.

---

# Git Repository vs Container Registry

Source code normally travels through Git repositories.

```text
source code
   ↓
Git
   ↓
GitHub
```

Container images travel through container registries.

```text
Dockerfile + application
        ↓
docker build
        ↓
container image
        ↓
registry
```

Examples of container registries include:

```text
Docker Hub
Amazon ECR
GitHub Container Registry
Google Artifact Registry
Azure Container Registry
```

---

# Registry vs Repository vs Tag

These terms are different.

## Registry

The registry is the server that stores container repositories.

Example:

```text
000000000000.dkr.ecr.us-east-1.localhost:5100
```

---

## Repository

A repository groups related container images.

Example:

```text
week6-web
```

---

## Tag

A tag is a human-readable reference to an image version.

Examples:

```text
v1
v2
latest
```

Conceptually:

```text
Registry
└── week6-web
    ├── v1
    ├── v2
    └── latest
```

---

# Local Images

Existing Week 6 images were inspected:

```bash
docker images | grep week6-day2-web
```

Images included:

```text
week6-day2-web:v1
week6-day2-web:v2
week6-day2-web:latest
```

The Day 6 lab used:

```text
week6-day2-web:v2
```

---

# Create ECR Repository

An ECR repository was created using:

```bash
aws ecr create-repository \
  --repository-name week6-web
```

The result included:

```text
repositoryArn:
arn:aws:ecr:us-east-1:000000000000:repository/week6-web

repositoryName:
week6-web

repositoryUri:
000000000000.dkr.ecr.us-east-1.localhost:5100/week6-web
```

The repository URI was stored:

```bash
ECR_URI=000000000000.dkr.ecr.us-east-1.localhost:5100/week6-web
```

---

# ECR Repository Structure

The lab architecture was:

```text
Floci ECR
   ↓
Registry
000000000000.dkr.ecr.us-east-1.localhost:5100
   ↓
Repository
week6-web
```

---

# Docker Image Tagging

The existing local image was tagged for the registry:

```bash
docker tag \
  week6-day2-web:v2 \
  "${ECR_URI}:v2"
```

This produced:

```text
week6-day2-web:v2

and

000000000000.dkr.ecr.us-east-1.localhost:5100/week6-web:v2
```

Both references pointed to the same image ID:

```text
5bfdc041282b
```

---

# What docker tag Does

`docker tag` does not rebuild the image.

It creates another reference to the same image.

Conceptually:

```text
week6-day2-web:v2 ───────────┐
                             │
                             ↓
                       same image
                             ↑
                             │
ECR/week6-web:v2 ────────────┘
```

---

# Registry Host

The registry host was extracted:

```bash
REGISTRY_HOST="${ECR_URI%%/*}"
```

Result:

```text
000000000000.dkr.ecr.us-east-1.localhost:5100
```

---

# ECR Authentication

Docker authenticated to ECR using:

```bash
aws ecr get-login-password \
  | docker login \
      --username AWS \
      --password-stdin \
      "$REGISTRY_HOST"
```

Result:

```text
Login Succeeded
```

---

# Real AWS Authentication Flow

In real AWS:

```text
AWS IAM credentials
      ↓
aws ecr get-login-password
      ↓
temporary ECR authentication token
      ↓
docker login
      ↓
docker push / pull
```

The ECR authentication token is temporary and is normally valid for 12 hours.

---

# Push Image to Registry

The image was pushed:

```bash
docker push "${ECR_URI}:v2"
```

Docker uploaded multiple image layers.

The final output contained:

```text
v2: digest:
sha256:5bfdc041282b36a898d5b9cddb44a7d526b0bda5ebd5e03ead244a9202f82fb6
```

This confirmed the registry accepted the image.

---

# Image Layers

Docker images are made from layers.

Conceptually:

```text
Image
├── base layer
├── nginx layer
├── configuration layer
└── application layer
```

When pushing an image, Docker uploads the required layers to the registry.

---

# Floci ECR Control-Plane Observation

The following commands returned empty results:

```bash
aws ecr list-images \
  --repository-name week6-web
```

and:

```bash
aws ecr describe-images \
  --repository-name week6-web
```

Result:

```text
imageIds: []
```

and:

```text
imageDetails: []
```

However, Docker push and pull worked successfully.

This showed an emulator-specific control-plane synchronization limitation in the current Floci environment.

---

# Control Plane vs Data Plane

The lab demonstrated an important distinction.

```text
AWS CLI ECR API
      ↓
ECR control plane
```

compared with:

```text
docker push / pull
      ↓
registry data plane
```

The Floci ECR data plane worked correctly even though the image-listing control-plane calls did not show the pushed image.

---

# Verify Registry by Pulling

The registry image was first pulled:

```bash
docker pull "${ECR_URI}:v2"
```

Docker reported:

```text
Status: Image is up to date
```

---

# Remove Local Registry Tag

The registry-qualified local reference was removed:

```bash
docker rmi "${ECR_URI}:v2"
```

This removed the tag:

```text
ECR_URI:v2
```

but did not remove the underlying image because other local tags still referenced it.

---

# Pull Image Again

The image was then pulled from the registry:

```bash
docker pull "${ECR_URI}:v2"
```

Result:

```text
Downloaded newer image
```

This proved that the registry actually stored the pushed image.

---

# Complete Push/Pull Proof

```text
local image
   ↓
docker tag
   ↓
registry-qualified image
   ↓
docker push
   ↓
registry
   ↓
remove local registry reference
   ↓
docker pull
   ↓
image restored locally
```

---

# Verify Registry Directly

The registry catalog was queried:

```bash
curl "http://${REGISTRY_HOST}/v2/_catalog"
```

Result:

```json
{"repositories":["week6-web"]}
```

This confirmed that the registry contained:

```text
week6-web
```

---

# Inspect Repository Tags

The repository tags were queried:

```bash
curl "http://${REGISTRY_HOST}/v2/week6-web/tags/list"
```

Initial result:

```json
{"name":"week6-web","tags":["v2"]}
```

This confirmed that the registry contained the `v2` tag.

---

# Image Tags vs Image Digests

The pushed image had the digest:

```text
sha256:5bfdc041282b36a898d5b9cddb44a7d526b0bda5ebd5e03ead244a9202f82fb6
```

A tag is human-friendly:

```text
week6-web:v2
```

A digest identifies exact content:

```text
week6-web@sha256:5bfd...
```

---

# Tag Characteristics

Tags can change.

Example:

```text
latest
```

may point to one image today and another image later.

Digests represent exact image content.

Conceptually:

```text
tag
v2
↓
human-friendly reference

digest
sha256:...
↓
content-specific identity
```

---

# Multiple Tags for One Image

A second tag was created:

```bash
docker tag \
  week6-day2-web:v2 \
  "${ECR_URI}:latest"
```

Both:

```text
week6-web:v2

and

week6-web:latest
```

pointed to the same image ID:

```text
5bfdc041282b
```

---

# zsh Variable Expansion Issue

An earlier command used:

```bash
"$ECR_URI:latest"
```

This produced an incorrect image reference:

```text
week6-webatest:latest
```

because zsh interpreted the variable expression unexpectedly.

The safer syntax is:

```bash
"${ECR_URI}:latest"
```

The braces explicitly show where the variable name ends.

General pattern:

```bash
"${VARIABLE}:tag"
"${VARIABLE}/path"
"${VARIABLE}-suffix"
```

---

# Push latest Tag

The correct tag was pushed:

```bash
docker push "${ECR_URI}:latest"
```

Docker reported many layers as:

```text
Layer already exists
```

or:

```text
Already exists
```

---

# Layer Reuse

The registry already contained the image layers from the `v2` push.

Therefore Docker did not need to upload identical layers again.

Conceptually:

```text
             ┌── v2
             │
same layers ─┤
             │
             └── latest
```

The tags were different, but the underlying content was the same.

---

# Content-Addressable Storage

Docker identifies image content using hashes.

If the same layer already exists in the registry, Docker can reuse it.

This reduces:

```text
network transfer
duplicate storage
push time
```

---

# Verify Multiple Tags

The registry was queried again:

```bash
curl "http://${REGISTRY_HOST}/v2/week6-web/tags/list"
```

Result:

```json
{
  "name": "week6-web",
  "tags": [
    "latest",
    "v2"
  ]
}
```

This confirmed both tags existed in the registry.

---

# Same Digest for Multiple Tags

Both pushes returned the same digest:

```text
sha256:5bfdc041282b36a898d5b9cddb44a7d526b0bda5ebd5e03ead244a9202f82fb6
```

Therefore:

```text
v2 ──────────┐
             ↓
      sha256:5bfd...
             ↑
latest ──────┘
```

---

# Container Distribution Workflow

The complete registry workflow is:

```text
Application source
        ↓
Dockerfile
        ↓
docker build
        ↓
local image
        ↓
docker tag
        ↓
registry-qualified reference
        ↓
docker login
        ↓
docker push
        ↓
container registry
        ↓
docker pull
        ↓
deployment environment
```

---

# Build Once, Run Everywhere

One of the main benefits of container registries is the ability to build an artifact once and distribute the same image.

```text
CI/CD
  ↓
build image once
  ↓
push image
  ↓
registry
  ├── development
  ├── staging
  └── production
```

This reduces differences between environments.

---

# Common Registry Troubleshooting

Useful checks include:

```text
docker images
      ↓
verify local image/tag

docker login
      ↓
verify authentication

docker push
      ↓
verify upload

docker pull
      ↓
verify download

registry API
      ↓
verify repository/tags
```

---

# Day 6 Troubleshooting Findings

## Problem 1

```text
aws ecr list-images
```

returned nothing.

### Finding

The Floci control-plane image listing did not synchronize with the registry data plane.

### Verification

The registry was confirmed using:

```bash
docker pull
```

and:

```bash
curl "http://${REGISTRY_HOST}/v2/_catalog"
```

---

## Problem 2

An image was incorrectly tagged as:

```text
week6-webatest:latest
```

### Cause

Shell variable expansion:

```bash
"$ECR_URI:latest"
```

### Fix

Use:

```bash
"${ECR_URI}:latest"
```

---

# Knowledge Check Summary

## Container Registry

A central service used to store and distribute container images.

---

## Repository

A logical collection of related container images inside a registry.

---

## Image Tag

A human-friendly reference such as:

```text
v1
v2
latest
```

---

## Image Digest

A content-specific SHA-256 identifier for an exact image artifact.

---

## docker tag

Creates another reference to an existing image.

It does not rebuild the image.

---

## docker push

Uploads image layers and metadata to a registry.

---

## docker pull

Downloads an image from a registry to a Docker host.

---

## ECR Authentication

```text
AWS credentials
      ↓
ECR authentication token
      ↓
docker login
```

---

## Layer Reuse

If layers already exist in a registry, Docker can reuse them instead of uploading them again.

---

# Day 6 Mental Model

```text
Local Docker
    ↓
build
    ↓
image
    ↓
tag
    ↓
login
    ↓
push
    ↓
registry
    ↓
pull
    ↓
another machine
```

And:

```text
Registry
└── Repository
    ├── tag:v2
    └── tag:latest
           ↓
      same digest
```

Most importantly:

```text
Source code travels through Git.

Container artifacts travel through
container registries.
```

---

# Final Result

Successfully demonstrated:

```text
Inspect local Docker images             ✅
Create ECR repository                   ✅
Capture repository URI                  ✅
Understand registry/repository/tag      ✅
Tag existing Docker image               ✅
Authenticate Docker to ECR              ✅
Push image to registry                  ✅
Observe image digest                    ✅
Understand image layers                 ✅
Remove local registry tag               ✅
Pull image from registry                ✅
Verify registry repository              ✅
Query repository tags                   ✅
Understand tag vs digest                ✅
Create multiple tags                    ✅
Observe layer reuse                     ✅
Understand content-addressable storage  ✅
Debug zsh variable expansion            ✅
Identify Floci ECR limitation           ✅
Complete push/pull lifecycle             ✅
```
