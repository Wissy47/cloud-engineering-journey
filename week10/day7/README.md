
# Week 10 — Day 7: CI/CD Capstone

## Project Overview

Designed and implemented a five-job GitHub Actions CI/CD
capstone that validates Python tests, builds and tests a
Docker application, verifies artifact integrity across
separate runners, checks Terraform infrastructure changes,
and performs development release verification.

The project demonstrates build-once, reuse-many artifact
promotion and automated failure prevention.

## Technologies

- GitHub Actions
- Python 3.13 and pytest
- Docker and Docker Buildx
- GitHub Actions artifacts
- SHA-256 checksums
- Terraform 1.16.5
- floci AWS-compatible emulator
- GitHub Environments

## Pipeline Architecture

```text
Python Tests          Docker Build + Health
       \                 /
        Artifact Verification
                 |
        Terraform Validation
                 |
       Development Release
```

## Pipeline Jobs

### 1. Python Quality Gate

Runs five automated pytest tests from the existing
Week 10 Day 2 application.

### 2. Docker Build and Health Gate

Builds the Week 10 Day 3 Docker application, runs its
container, and verifies the /health endpoint.

After successful verification:

- Exports the Docker image to application-image.tar.
- Generates application-image.tar.sha256.
- Uploads both files to GitHub Actions artifact storage.

### 3. Artifact Verification

Runs on a separate GitHub-hosted runner.

- Downloads the saved image archive and checksum.
- Verifies integrity using sha256sum -c.
- Loads the original image using docker load.
- Runs the loaded image.
- Verifies the /health endpoint.
- Cleans up the temporary container.

The image is not rebuilt.

### 4. Terraform Infrastructure Quality Gate

Reuses the Week 10 Day 4 Terraform configuration.

- Checks formatting.
- Initializes the locked Terraform provider.
- Validates the configuration.
- Starts an isolated floci instance.
- Generates a Terraform plan.
- Removes the temporary floci container.

Terraform apply is deliberately not executed.

### 5. Development Release Verification

Uses the GitHub development environment.

Checks the expected configuration:

- APP_ENV=development
- LOG_LEVEL=DEBUG

Then downloads the original application artifact again,
verifies its checksum, loads the image, checks its health,
and removes the temporary container.

This is release verification, not a persistent deployment.

## Artifact Promotion and Integrity

The image is built once and uploaded as a workflow artifact.

Both downstream jobs reuse the original image archive
rather than rebuilding the application.

SHA-256 checksum verification is performed before the
downloaded Docker image is loaded.

Checksum verification establishes file integrity relative
to the recorded checksum; it does not prove that the
image is vulnerability-free.

## Failure and Recovery Testing

An intentional corruption test appended data to the
downloaded Docker archive before checksum verification.

Expected and observed results:

- Python tests: Success
- Docker build: Success
- Artifact verification: Failure
- Terraform validation: Skipped
- Development release: Skipped

The temporary corruption step was then removed.

The recovery run completed all five jobs successfully.

## Verified CI Evidence

### Initial Successful Capstone

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/40084072777

### Controlled Artifact Integrity Failure

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/40084917187

### Successful Recovery

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/40085491541

## Results

- Five automated jobs successfully integrated.
- Five Python tests passed.
- Docker application health checks passed.
- Docker image reused across independent runners.
- Uploaded artifact passed SHA-256 verification.
- Terraform plan proposed one resource.
- No Terraform infrastructure was applied.
- Controlled checksum failure blocked downstream jobs.
- Recovery restored successful workflow execution.
- Temporary test containers were cleaned up.

## Limitations

- No persistent application deployment was performed.
- No production environment was modified.
- Terraform was planned but not applied.
- Image artifacts are stored temporarily in GitHub Actions.
- Container registry promotion, image signing, vulnerability
  scanning, and production rollout are outside this capstone.

## Key Lessons

1. Build once and reuse the verified artifact.
2. Separate application, artifact, and infrastructure checks.
3. Use job dependencies to prevent unsafe progression.
4. Verify artifact integrity before running downloaded images.
5. Test failure behavior as well as successful execution.
6. Keep CI test infrastructure isolated and disposable.
7. Preserve logs, workflow runs, and documentation as evidence.
