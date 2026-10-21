
# Week 10 — Day 4: Terraform Automation with GitHub Actions

## Project Overview

Built a Terraform CI pipeline using GitHub Actions to automate formatting, provider initialization, configuration validation, and infrastructure planning against a disposable floci AWS-compatible environment.

The workflow reports proposed infrastructure changes without executing `terraform apply`.

## Learning Objectives

- Automate Terraform checks through GitHub Actions.
- Use a committed provider dependency lock file.
- Troubleshoot cross-platform provider checksum issues.
- Run floci inside an isolated GitHub-hosted environment.
- Use Terraform detailed exit codes correctly.
- Clean up temporary containers after successful or failed jobs.

## Environment

| Component | Configuration |
|---|---|
| Local machine | macOS Apple Silicon |
| Local Terraform | v1.16.5, darwin_arm64 |
| GitHub runner | ubuntu-latest |
| CI Terraform | v1.16.5 |
| AWS provider | v6.69.1 |
| AWS-compatible emulator | floci |
| CI floci image | floci/floci:2.3.0 |
| AWS region | us-east-1 |
| Emulator endpoint | http://localhost:4566 |
| Terraform resource | aws_s3_bucket.ci_artifacts |

## Project Files

```text
week10/day4/
├── .gitignore
├── .terraform.lock.hcl
├── main.tf
├── provider.tf
├── versions.tf
└── README.md

.github/workflows/week10-day4.yml
```

## Architecture

```text
Developer
    |
    v
GitHub Repository
    |
    v
GitHub Actions — Ubuntu Runner
    |
    +-- Checkout repository
    +-- Install Terraform
    +-- Check formatting
    +-- Initialize locked provider
    +-- Validate configuration
    |
    +-- Start disposable floci
    +-- Wait for health endpoint
    |
    +-- Generate Terraform plan
    |       |
    |       +-- No changes: exit 0
    |       +-- Error: exit 1
    |       +-- Proposed changes: exit 2
    |
    +-- Show diagnostics on failure
    +-- Clean up floci
    |
    v
CI Result
```

The floci instance runs on the GitHub-hosted runner, not on the developer's Mac.

## Terraform Configuration

The project declares an S3 bucket:

```hcl
resource "aws_s3_bucket" "ci_artifacts" {
  bucket = "week10-day4-terraform-ci-demo"
}
```

The AWS provider uses dummy emulator credentials and an S3 endpoint on localhost:4566.

Path-style S3 addressing is enabled for emulator compatibility.

No real AWS resources are created by this workflow.

## Initial Local Validation

Executed:

```bash
terraform fmt -recursive
terraform init -input=false
terraform validate
terraform fmt -check -recursive
```

Results:

- Terraform initialized successfully.
- AWS provider v6.69.1 installed.
- Formatting check passed.
- Configuration validation passed.

## GitHub Actions Validation

Created `.github/workflows/week10-day4.yml`.

The workflow includes:

- Push, pull request, and manual triggers.
- Read-only repository permissions.
- Terraform v1.16.5 setup.
- Formatting checks.
- Provider initialization using `-lockfile=readonly`.
- Terraform configuration validation.

## Troubleshooting: Provider Checksum Mismatch

The first GitHub Actions workflow failed during Terraform validation.

The Linux runner reported that the AWS provider package did not match any checksums recorded in `.terraform.lock.hcl`.

The local lock file was initially generated on macOS ARM64.

Investigated and corrected the provider checksums using:

```bash
terraform providers lock \
  -platform=darwin_arm64 \
  -platform=linux_amd64
```

Terraform retrieved signed checksums for both platforms and updated the lock file without changing the selected provider version.

Committed the correction:

`e65790f` — Fix Terraform provider checksums for Linux CI runner.

The subsequent GitHub Actions run passed.

Successful validation run:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39633449851

## Disposable floci Environment

Extended the workflow to run:

```bash
docker run -d \
  --name week10-day4-floci \
  -p 127.0.0.1:4566:4566 \
  floci/floci:2.3.0
```

The workflow waits for:

```text
http://127.0.0.1:4566/_localstack/health
```

This avoided publicly exposing the Mac's local floci environment.

The CI emulator used a separate, temporary environment without mounting the Docker socket.

## Terraform Plan Automation

Executed Terraform with:

```bash
terraform plan \
  -input=false \
  -no-color \
  -refresh=false \
  -detailed-exitcode
```

Handled exit codes:

| Code | Meaning | CI handling |
|---|---|---|
| 0 | No changes | Success |
| 1 | Terraform error | Failure |
| 2 | Changes proposed | Success with change report |

The workflow did not execute `terraform apply`.

## Verified Plan Output

The GitHub Actions logs reported:

```text
# aws_s3_bucket.ci_artifacts will be created

Plan: 1 to add, 0 to change, 0 to destroy.

Terraform plan succeeded: infrastructure changes proposed.
```

The S3 bucket was planned, not created.

Initial successful plan run:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39642089483

## Automatic Cleanup

Added a cleanup step using:

```yaml
- name: Clean up disposable floci
  if: always()
  run: |
    if docker container inspect week10-day4-floci > /dev/null 2>&1; then
      docker rm -f week10-day4-floci
      echo "Disposable floci container removed."
    else
      echo "No disposable floci container to remove."
    fi
```

This attempts cleanup regardless of earlier step success or failure.

The final workflow run confirmed:

```text
Disposable floci container removed.
```

Final successful CI run:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39690595190

## Safety and State Management

- No automatic Terraform apply.
- No changes to Week 9 infrastructure.
- No production AWS credentials.
- No publicly exposed local emulator.
- Provider lock file committed.
- Terraform state and downloaded providers excluded from Git.
- Disposable CI infrastructure cleaned up.
- Existing Mac-based floci container preserved.

## Key Lessons

1. Terraform validation and planning test different aspects of configuration.
2. A successful plan does not mean infrastructure was created.
3. Dependency lock files improve reproducibility.
4. Cross-platform provider checksums matter in CI.
5. Detailed exit code 2 indicates proposed changes, not an error.
6. An isolated emulator makes infrastructure testing repeatable.
7. Health checks reduce startup-related failures.
8. Diagnostic logs support structured troubleshooting.
9. Cleanup should execute even when earlier workflow steps fail.
10. Successful CI does not replace controlled deployment approvals.

## GitHub Evidence

- Initial validation workflow: `9ca18c4`
- Provider checksum correction: `e65790f`
- Disposable floci Terraform planning: `f9b8767`
- Automatic cleanup: `85970de`

Verified workflow:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39690595190

## Outcome

Successfully automated Terraform validation and infrastructure planning using GitHub Actions and an isolated floci environment, with safe failure handling and cleanup.
