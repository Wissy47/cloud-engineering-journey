
# Week 10 — Day 6: CI/CD Pipeline Integration Challenge

## Project Overview

Built a four-job GitHub Actions pipeline integrating automated Python testing, Docker image building, Terraform validation and planning, and a controlled development deployment simulation.

Verified successful execution, failure propagation, job dependencies, cleanup, and recovery.

No real application or infrastructure was deployed.

## Environment

| Component | Configuration |
|---|---|
| Repository | Wissy47/cloud-engineering-journey |
| CI/CD platform | GitHub Actions |
| Runner | ubuntu-latest |
| Python | 3.13 |
| Testing framework | pytest |
| Container platform | Docker / Buildx |
| Docker target architecture | linux/amd64 |
| Terraform | 1.16.5 |
| AWS-compatible emulator | floci/floci:2.3.0 |
| Deployment environment | development |

## Workflow

`.github/workflows/week10-day6.yml`

The workflow supports:

- Pushes to `main` matching configured paths
- Pull requests targeting `main` matching configured paths
- Manual execution with `workflow_dispatch`

Repository token permissions are limited to `contents: read`.

## Architecture

```text
             GitHub Actions
                   |
          +--------+--------+
          |                 |
          v                 v
     Python Tests      Docker Build
          |                 |
          |                 v
          |            Health Check
          |                 |
          +--------+--------+
                   |
                   v
          Terraform Validation
                   |
                   v
          Disposable floci
                   |
                   v
             Terraform Plan
                   |
                   v
        Development Environment
                   |
                   v
          Deployment Simulation
```

## Job 1 — Python Automated Tests

Reused the existing Day 2 calculator project:

`week10/day2/`

The job:

1. Checks out the repository.
2. Installs Python 3.13.
3. Installs dependencies.
4. Runs pytest.

Verified result:

```text
5 passed in 0.02s
```

## Job 2 — Docker Build and Health Verification

Reused the existing Day 3 Python API:

`week10/day3/`

The job:

1. Builds a Linux AMD64 Docker image.
2. Loads the image into the runner's Docker engine.
3. Starts a temporary application container.
4. Tests the `/health` endpoint.
5. Displays container logs if health verification fails.
6. Removes the temporary container.

Verified:

```text
Day 6 container health check passed
Day 6 test container removed
```

The image was not published to a registry.

## Job 3 — Terraform Validation and Planning

Reused the existing Day 4 Terraform project:

`week10/day4/`

Dependencies:

```yaml
needs: [python-tests, docker-build]
```

The job:

1. Installs Terraform 1.16.5.
2. Checks formatting.
3. Initializes providers using the committed dependency lock file.
4. Validates Terraform configuration.
5. Starts an isolated floci container.
6. Waits for emulator health.
7. Generates a Terraform plan.
8. Cleans up the floci container.

Verified:

```text
Day 6 floci health check passed
Plan: 1 to add, 0 to change, 0 to destroy.
Terraform plan succeeded: changes proposed
Day 6 floci container removed
```

The plan proposed creating an S3 bucket in the emulator environment.

Terraform did not execute `apply`.

## Job 4 — Deployment Simulation

Dependencies:

```yaml
needs: [python-tests, docker-build, terraform-validation]
```

The job uses the GitHub `development` environment.

It validates:

```text
APP_ENV=development
LOG_LEVEL=DEBUG
```

Verified:

```text
All required quality gates passed.
Development deployment simulation successful.
No infrastructure was modified.
```

The simulation did not transfer or deploy the Docker image.

## Initial Successful Pipeline

The first integrated workflow execution passed all four jobs.

Evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39970643509

## Controlled Failure Simulation

Temporarily introduced an intentional failure step before pytest:

```yaml
- name: Simulate Python quality gate failure
  run: |
    echo "Intentional Day 6 pipeline failure test"
    exit 1
```

Verified results:

| Job | Result |
|---|---|
| Python Automated Tests | Failed as intended |
| Build and Test Docker Image | Succeeded |
| Validate and Plan Terraform | Skipped |
| Simulate Development Deployment | Skipped |

This confirmed that job dependencies prevented downstream execution after an upstream failure.

Evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39979616903

## Recovery Verification

Removed the temporary failure step and restored the original pytest job.

Pushed the corrected workflow.

All four jobs passed again.

Evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39981418154

## Safety and Cleanup

- Existing Day 2, Day 3 and Day 4 projects were reused.
- No changes were made to the Mac's existing floci environment.
- The GitHub runner used a disposable floci instance.
- Temporary Docker and floci containers were removed.
- No real AWS credentials were needed.
- Terraform performed planning only.
- Deployment was simulated, not executed.
- The controlled failure was removed and recovery verified.

## Key Lessons

1. Independent jobs can execute in parallel.
2. `needs` establishes execution dependencies.
3. A failed required job normally causes dependent jobs to be skipped.
4. Separate jobs do not automatically share filesystem contents or Docker images.
5. Building an image does not prove that its application is healthy.
6. Health checks provide runtime verification.
7. Terraform exit code 2 means changes are proposed when using `-detailed-exitcode`.
8. Disposable test infrastructure supports repeatable CI runs.
9. Cleanup should execute even when earlier steps fail.
10. Production deployment requires additional controls beyond successful CI.
11. Artifact promotion should reuse the exact verified build across environments.
12. Failure and recovery tests help verify pipeline quality gates.

## GitHub Evidence

Workflow:

`.github/workflows/week10-day6.yml`

Initial success:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39970643509

Controlled failure:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39979616903

Successful recovery:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39981418154

## Outcome

Successfully integrated four CI/CD jobs and verified that the pipeline executes required quality checks, prevents downstream execution after an upstream failure, and returns to a healthy state after recovery.
