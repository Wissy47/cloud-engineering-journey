
# Week 10 — Day 2: Continuous Integration & Automated Testing

## Objective

Implement automated Python tests using pytest and configure
GitHub Actions to execute those tests whenever relevant code
changes are pushed to GitHub.

## Environment

| Component | Configuration |
|---|---|
| Local OS | macOS Apple Silicon M1 |
| Local Python | 3.13.0 |
| CI runner | GitHub-hosted Ubuntu |
| CI Python | 3.13.16 |
| Testing framework | pytest 8.4.2 |
| Repository | cloud-engineering-journey |

## Key Concepts

### Continuous Integration

Continuous Integration involves frequently integrating code
changes and automatically validating them using tests, builds,
and other checks.

### Unit Testing

Unit tests verify individual functions or components.

### Integration Testing

Integration tests verify that multiple components work together.

### Automated Testing

Automated tests compare application behavior against expected
results and report successful or failed assertions.

## Project Structure

```text
week10/day2/
├── .gitignore
├── app/
│   ├── __init__.py
│   └── calculator.py
├── tests/
│   └── test_calculator.py
├── requirements.txt
└── README.md
```

The local .venv directory and generated Python caches are
excluded from Git.

## Application Implementation

Created four Python functions:

- add(a, b)
- subtract(a, b)
- multiply(a, b)
- divide(a, b)

The divide function raises ValueError when the divisor is zero.

## Automated Tests

Created five tests:

1. test_add
2. test_subtract
3. test_multiply
4. test_divide
5. test_divide_by_zero

The tests use assertions and pytest.raises to verify normal
behavior and expected exceptions.

## Local Testing

Created and activated an isolated Python environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Installed the testing dependency:

```bash
python -m pip install -r requirements.txt
```

Executed:

```bash
python -m pytest -v
```

Result:

```text
5 passed in 0.03s
```

## GitHub Actions Architecture

Developer pushes code
        |
        v
GitHub Repository
        |
        v
GitHub Actions Workflow
        |
        v
GitHub-hosted Ubuntu Runner
        |
        +-- Checkout repository
        |
        +-- Set up Python 3.13
        |
        +-- Install dependencies
        |
        +-- Execute pytest
        |
        v
CI Success or Failure

## Workflow Configuration

Workflow file:

.github/workflows/week10-day2.yml

Configured:

- Push trigger for main
- Pull request trigger targeting main
- Path filters for Day 2 files and workflow configuration
- Manual workflow_dispatch trigger
- Read-only repository contents permission
- GitHub-hosted Ubuntu runner
- Python 3.13
- Working directory: week10/day2

## GitHub Actions Verification

Workflow run ID: 39434695429

Trigger: push

Conclusion: Success

CI test results:

```text
5 passed in 0.02s
```

Evidence:

https://github.com/Wissy47/cloud-engineering-journey/actions/runs/39434695429

## Failure Investigation

Performed a controlled local failure simulation.

Executed:

```bash
python -c "assert 2 + 2 == 5"
```

Python raised AssertionError and exited with status code 1.

Created a temporary pytest test outside the repository
to compare expected=500 against actual=400.

Result:

```text
FAILED test_expected_total
E assert 400 == 500
1 failed in 0.06s
```

The pytest process returned exit code 1.

Removed the temporary test after verification.

## Troubleshooting Lessons

1. Passing local tests does not guarantee CI will pass.
2. Runner operating systems and Python versions may differ.
3. Dependency installation failures can prevent tests from running.
4. A failing assertion demonstrates a detected mismatch.
5. Nonzero exit codes communicate failure to automation tools.
6. CI job logs help identify failing commands and test cases.
7. Failed tests should be investigated before changing expectations.
8. Virtual environments should not be committed to repositories.
