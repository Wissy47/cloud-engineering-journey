
# Week 10 — Day 3: Docker Build Automation & Amazon ECR

## Objective

Build and verify a containerized Python application, automate
the image build through GitHub Actions, and publish and retrieve
the image using a local floci-backed container registry.

## Environment

| Component | Configuration |
|---|---|
| Local development | macOS Apple Silicon M1 |
| Docker Engine | 29.7.2 |
| Docker Buildx | 0.36.1 |
| Local image architecture | linux/arm64 |
| GitHub Actions runner | Ubuntu Linux |
| CI image architecture | linux/amd64 |
| AWS-compatible environment | floci |
| AWS region | us-east-1 |
| ECR API endpoint | http://localhost:4566 |
| Working registry endpoint | http://127.0.0.1:5100 |

## Architecture

Developer pushes source code
        |
        v
GitHub Repository
        |
        v
GitHub Actions
        |
        +-- Checkout repository
        +-- Set up Docker Buildx
        +-- Build linux/amd64 image
        +-- Inspect architecture
        +-- Run container
        +-- Verify /health
        |
        v
CI Success

Separate local publishing workflow:

Docker Build (ARM64)
        |
        v
Docker Tag
        |
        v
floci-backed Registry (127.0.0.1:5100)
        |
        v
Docker Pull
        |
        v
Run Container and Verify

The GitHub-hosted runner did not publish directly to the
local floci registry.

## Project Structure

```text
week10/day3/
├── .dockerignore
├── .gitignore
├── Dockerfile
├── app/
│   └── main.py
└── README.md
```

GitHub Actions workflow:

.github/workflows/week10-day3.yml

## Application

Implemented a Python HTTP server using the standard library.

Endpoints:

- GET /health — returns HTTP 200 and service health JSON.
- Other paths — return HTTP 404.

The application listens on port 8080 inside its container.

## Local Docker Build

Executed:

```bash
docker build \
  -t week10-day3-api:local \
  ./week10/day3
```

Verified architecture:

```bash
docker image inspect week10-day3-api:local \
  --format 'OS={{.Os}} Architecture={{.Architecture}}'
```

Result:

```text
OS=linux Architecture=arm64
```

## Local Container Verification

Started the application:

```bash
docker run -d \
  --name week10-day3-api-test \
  -p 127.0.0.1:8093:8080 \
  week10-day3-api:local
```

Tested:

```bash
curl -i http://127.0.0.1:8093/health
curl -i http://127.0.0.1:8093/not-found
```

Results:

- /health returned HTTP 200.
- /not-found returned HTTP 404.
- Container logs confirmed both requests.

## GitHub Actions Automation

Created:

.github/workflows/week10-day3.yml

Configured:

- Push trigger on main
- Pull request trigger targeting main
- Manual workflow_dispatch trigger
- Read-only repository permissions
- Docker Buildx
- Linux AMD64 image build
- Local image loading on the runner
- Architecture inspection
- Container health verification

The workflow uses:

- push: false
- load: true
- platforms: linux/amd64

The image was loaded into the GitHub-hosted runner's local
Docker image store, not pushed to an external registry.

## Verified CI Execution

Workflow commit: 05ed0d8

Workflow run ID: 39478649773

Result: Success

Image architecture:

```text
OS=linux Architecture=amd64
```

Health-check result:

```text
{"status": "healthy", "service": "week10-day3-api"}
Container health check passed
```

Evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39478649773

## Local ECR Repository

Created a dedicated repository:

```bash
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 \
  ecr create-repository \
  --repository-name week10-day3-api
```

The repository management API returned:

```text
000000000000.dkr.ecr.us-east-1.localhost:4566/week10-day3-api
```

The initial repository image list was empty.

Existing Week 6 repositories were preserved.

## Registry Troubleshooting

The floci health endpoint returned HTTP 200.

However:

- http://localhost:4566/v2/ returned HTTP 404 with NoSuchBucket.
- The advertised ECR hostname on port 4566 returned HTTP 503.
- The backing registry was running on port 5100.
- http://127.0.0.1:5100/v2/ returned HTTP 200.

floci logs also reported a Docker bridge endpoint attachment warning.

The investigation indicated an endpoint routing or integration
problem, rather than a failure of the Docker image build.

No Docker networks or existing floci containers were recreated.

## Image Tagging

Tagged the local image for the working registry:

```bash
docker tag \
  week10-day3-api:local \
  127.0.0.1:5100/week10-day3-api:v1
```

Both tags referenced the same local image ID:

```text
sha256:9d434d89a4832211d74849901a05480a66b9c4f3663bf51454bf6b10799bbe2f
```

## Image Publishing

Pushed the image:

```bash
docker push 127.0.0.1:5100/week10-day3-api:v1
```

Push result:

```text
v1: digest: sha256:9d434d89a4832211d74849901a05480a66b9c4f3663bf51454bf6b10799bbe2f
```

Verified the registry tag:

```bash
curl -sS \
  http://127.0.0.1:5100/v2/week10-day3-api/tags/list
```

Result:

```json
{"name":"week10-day3-api","tags":["v1"]}
```

## ECR Emulator Limitation

After the successful registry push, floci returned:

```json
{"imageIds":[]}
```

from the ECR list-images operation.

The backing Docker Registry API correctly returned the v1 tag.

This demonstrated that the registry data plane worked, while
the ECR control plane did not reflect the published image.

## Pull Verification

Removed only the local registry-qualified image reference:

```bash
docker rmi 127.0.0.1:5100/week10-day3-api:v1
```

Pulled it again:

```bash
docker pull 127.0.0.1:5100/week10-day3-api:v1
```

Result:

```text
Status: Downloaded newer image
```

Verified ARM64 architecture and matching image ID.

## Pulled Container Verification

Executed:

```bash
docker run -d \
  --name week10-day3-registry-test \
  -p 127.0.0.1:8094:8080 \
  127.0.0.1:5100/week10-day3-api:v1
```

The /health endpoint returned HTTP 200.

Docker logs confirmed successful HTTP handling.

## Cleanup

Stopped and removed only the two Day 3 test containers:

```bash
docker stop \
  week10-day3-api-test \
  week10-day3-registry-test

docker rm \
  week10-day3-api-test \
  week10-day3-registry-test
```

Verified no Day 3 test containers remained.

Preserved:

- Local Docker image
- Published registry image
- Day 3 ECR repository
- Existing Week 6 repositories
- Existing floci and other lab containers

## Lessons Learned

1. Docker images and containers are different resources.
2. Tags provide names and versions for image references.
3. Docker Buildx supports architecture-specific builds.
4. Local and CI image architectures can differ.
5. A successful image build does not prove application health.
6. Automated health checks help validate runtime behavior.
7. Registry control-plane and data-plane operations are distinct.
8. floci may not fully synchronize ECR metadata with its registry.
9. A successful push should be followed by pull verification.
10. Structured troubleshooting protects existing infrastructure.
11. Container cleanup does not require deleting images.
12. Published images can be reused without rebuilding them.
