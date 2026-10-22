
# Week 10 — Day 5: Environments, Secrets & Deployment Strategies

## Project Overview

Configured GitHub Actions deployment environments, implemented an environment-aware deployment simulation, verified environment-specific configuration, and tested safe failure handling and recovery.

Studied deployment protection rules and rolling, blue-green, and canary deployment strategies.

No real infrastructure was deployed or modified.

## Environment

| Component | Configuration |
|---|---|
| Repository | Wissy47/cloud-engineering-journey |
| CI/CD platform | GitHub Actions |
| Runner | ubuntu-latest |
| Workflow | .github/workflows/week10-day5.yml |
| Trigger | workflow_dispatch |
| Environments | development, staging, production |
| Repository permissions | contents: read |
| Deployment type | Simulation only |

## Architecture

```text
Developer
    |
    v
Manual GitHub Actions Trigger
    |
    v
Select Target Environment
    |
    +-- development
    +-- staging
    +-- production
    |
    v
GitHub Environment Configuration
    |
    +-- APP_ENV
    +-- LOG_LEVEL
    |
    v
Validate Configuration
    |
    +-- Valid --> Simulate Deployment --> Success
    |
    +-- Invalid --> Exit 1 --> Failure
```

## Deployment Environments

Created three GitHub environments:

| Environment | APP_ENV | LOG_LEVEL |
|---|---|---|
| development | development | DEBUG |
| staging | staging | INFO |
| production | production | WARNING |

Each environment contains its own configuration variables.

GitHub environments organize deployment configuration and protection policies. They do not automatically provision infrastructure.

## GitHub Actions Secrets vs Variables

Variables are intended for non-sensitive configuration, such as environment names and log levels.

Secrets are intended for sensitive values, such as API keys, access tokens, and credentials.

GitHub encrypts stored secrets and attempts to mask recognized secret values in workflow logs.

However, workflows must still avoid exposing sensitive values.

For AWS deployments, short-lived credentials obtained through OIDC are generally preferable to long-lived static access keys.

No real secrets were created or used during this lab.

## Environment-Aware Workflow

Created:

`.github/workflows/week10-day5.yml`

The workflow uses a manual trigger with an environment selection input:

```yaml
on:
  workflow_dispatch:
    inputs:
      target_environment:
        description: "Select deployment environment"
        required: true
        type: choice
        options:
          - development
          - staging
          - production
```

The deployment job references the selected environment:

```yaml
environment:
  name: ${{ inputs.target_environment }}
```

It loads configuration using:

```yaml
env:
  APP_ENV: ${{ vars.APP_ENV }}
  LOG_LEVEL: ${{ vars.LOG_LEVEL }}
  TARGET_ENV: ${{ inputs.target_environment }}
```

## Environment Validation

The workflow rejects missing configuration:

```bash
if [[ -z "$APP_ENV" || -z "$LOG_LEVEL" ]]; then
  echo "Required environment variables are missing."
  exit 1
fi
```

It rejects environment mismatches:

```bash
if [[ "$APP_ENV" != "$TARGET_ENV" ]]; then
  echo "Environment mismatch detected."
  exit 1
fi
```

It validates permitted environment and logging combinations:

```bash
case "$APP_ENV:$LOG_LEVEL" in
  development:DEBUG|staging:INFO|production:WARNING)
    echo "Environment configuration verified."
    ;;
  *)
    echo "Unexpected configuration for selected environment."
    exit 1
    ;;
esac
```

This prevents the simulation step from running when configuration validation fails.

## Development Verification

Triggered the development environment manually.

Result:

```text
Environment configuration verified.
Target environment: development
Log level: DEBUG
Deployment simulation successful.
No infrastructure was modified.
```

GitHub evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39742459035

## Staging Verification

Triggered the staging environment using the same workflow.

Result:

```text
Environment configuration verified.
Target environment: staging
Log level: INFO
Deployment simulation successful.
```

GitHub evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39745283671

## Production Verification

Triggered the production environment simulation.

Result:

```text
Environment configuration verified.
Target environment: production
Log level: WARNING
Deployment simulation successful.
No infrastructure was modified.
```

GitHub evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39749518931

The production simulation did not deploy any application or infrastructure.

## Deployment Protection Rules

Inspected GitHub production environment protection settings.

Available controls included:

- Required reviewers
- Wait timer
- Custom deployment protection rules
- Administrator bypass settings
- Deployment branch and tag restrictions

At the time of inspection:

- Required reviewers were not enabled.
- Wait timer was not enabled.
- Administrator bypass was allowed.
- Deployment branches and tags had no restrictions.
- No environment secrets were configured.

These settings were inspected but not changed during the exercise.

Manual workflow execution is not equivalent to independent deployment approval.

## Deployment Strategies

### Rolling Deployment

Gradually replaces application instances with a new version.

Example: Upgrade two of six servers at a time while monitoring health.

Advantages:

- Gradual rollout
- Reduced need for a full duplicate environment

Tradeoffs:

- Old and new application versions temporarily coexist.
- Rollback can require replacing updated instances.

### Blue-Green Deployment

Maintains two environments:

- Blue: existing release
- Green: new release

Traffic switches to the new release after verification.

Advantages:

- Clear separation between releases
- Potentially fast rollback

Tradeoffs:

- Additional infrastructure capacity
- Database compatibility considerations

### Canary Deployment

Routes a small percentage of traffic to the new application version.

Example: Start with 5%, observe health metrics, and gradually increase exposure.

Useful monitoring metrics:

- HTTP 5xx error rate
- P95 response latency
- Successful transaction rate
- CPU and memory usage
- Application logs

A rollout should stop or reverse when significant problems are detected.

## Controlled Failure Simulation

Temporarily modified the development environment configuration:

```text
APP_ENV=development
LOG_LEVEL=WARNING
```

The combination was intentionally invalid.

Triggered the development workflow.

Observed:

```text
Unexpected configuration for selected environment.
Process completed with exit code 1.
```

GitHub Actions correctly skipped the deployment simulation step.

Failed-run evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39753192810

## Recovery Verification

Restored the correct development configuration:

```text
APP_ENV=development
LOG_LEVEL=DEBUG
```

Triggered the workflow again.

The environment validation and deployment simulation both passed.

Recovery evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39753468676

This demonstrated fail-closed validation and successful recovery after correcting configuration.

## Security Practices

1. Keep sensitive values in secrets rather than ordinary variables.
2. Avoid printing credentials in workflow logs.
3. Use separate credentials for different environments.
4. Prefer short-lived cloud credentials where appropriate.
5. Validate configuration before deployment.
6. Apply branch and reviewer restrictions to sensitive environments.
7. Maintain rollback procedures for real deployments.
8. Test failures in isolated environments rather than live production.
9. Grant only necessary workflow permissions.
10. Keep deployment configuration and authorization as separate controls.

## Key Lessons

- Development, staging, and production serve different purposes.
- Environment-specific configuration reduces accidental cross-environment operations.
- A shared workflow can deploy consistently to different environments.
- Successful configuration validation does not mean deployment authorization.
- Manual dispatch and required approvals are separate controls.
- Branch restrictions help limit eligible deployment sources.
- The same verified artifact can be promoted between environments.
- Rolling, blue-green, and canary deployments manage release risk differently.
- Configuration errors should stop deployment before execution.
- Successful recovery should be verified after troubleshooting.

## GitHub Evidence

Workflow:

`.github/workflows/week10-day5.yml`

Development:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39742459035

Staging:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39745283671

Production:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39749518931

Expected failure:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39753192810

Successful recovery:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39753468676

## Outcome

Successfully configured and verified three environment-aware deployment simulations, inspected production protection controls, and demonstrated safe rejection and recovery from invalid environment configuration.
