
# Week 10 — Day 1: CI/CD Fundamentals and GitHub Actions

## Objective

Understand CI/CD fundamentals and implement a working
GitHub Actions workflow using automatic and manual triggers.

## Environment

- Local development: macOS Apple Silicon M1
- Git repository: cloud-engineering-journey
- GitHub Actions runner: Ubuntu 24.04
- Workflow: .github/workflows/week10-day1.yml
- Python on runner: 3.12.3

## Key Concepts

### Continuous Integration

Continuous Integration is the practice of frequently
integrating code changes and automatically validating
them with builds, tests, and other checks.

### Continuous Delivery

Code that passes the required checks is maintained
in a deployable state. Production release may still
require manual approval.

### Continuous Deployment

Changes that pass all required checks are automatically
deployed to production without a separate manual
deployment decision.

## Architecture

Developer
    |
    v
GitHub Repository
    |
    +-- Push to main (with matching file changes)
    |
    +-- Manual workflow_dispatch
    |
    v
GitHub Actions Workflow
    |
    v
GitHub-hosted Ubuntu Runner
    |
    +-- Display welcome message
    +-- Display operating system information
    +-- Verify Python execution
    |
    v
Workflow Result (Success or Failure)

## Implementation

Created the workflow file:

.github/workflows/week10-day1.yml

The workflow contains one job named `introduction`
with three command-execution steps.

Configuration includes:

- Automatic push trigger on main with a path filter
- Manual workflow_dispatch trigger
- Read-only repository contents permission
- ubuntu-latest runner

## Git Commands

Stage and commit the workflow:

```bash
git add .github/workflows/week10-day1.yml
git commit -m "Add Week 10 Day 1 introductory GitHub Actions workflow"
git push origin main
```

Inspect GitHub Actions runs:

```bash
gh run list --workflow week10-day1.yml --limit 5
```

## Practical Verification

### Automatic Execution

- Trigger: push
- Run ID: 39381839936
- Result: Success
- Duration: 9 seconds

Evidence:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39381839936

### Manual Execution

- Trigger: workflow_dispatch
- Run ID: 39384590943
- Result: Success
- Duration: 8 seconds

Evidence:
https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39384590943

Both runs used commit 093c9dd.

## Runner Verification

The runner reported:

- Ubuntu 24.04.5 LTS
- Linux x86_64 architecture
- GitHub-hosted Azure infrastructure
- Python 3.12.3

The local development environment was macOS ARM64,
but execution occurred remotely on Linux x86_64.

## Lessons Learned

1. Workflows automate tasks in response to events.
2. Jobs run on configured runners.
3. Steps execute commands or reusable actions.
4. Push triggers can use branch and path filters.
5. workflow_dispatch enables manual execution.
6. A failed command normally causes its step and job to fail.
7. Runner environments can differ from local machines.
8. Repository permissions should follow least privilege.
9. CI checks are not the same as a complete deployment pipeline.
10. GitHub Actions provides execution logs for troubleshooting.