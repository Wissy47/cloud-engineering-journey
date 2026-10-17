# Week 9 — Day 4: Terraform State Management & Infrastructure Drift

## Objectives

- Explain the relationship between Terraform configuration, state, and actual infrastructure.
- Inspect state and outputs using the Terraform CLI.
- Detect changes made outside Terraform (infrastructure drift).
- Compare normal plans with refresh-only plans.
- Record an external deletion using `terraform apply -refresh-only`.
- Understand local versus remote state, state locking, and sensitive state data.
- Safely clean up an isolated floci S3 lab resource.

## Environment

| Component | Value |
|---|---|
| Host | Apple Silicon macOS (`darwin_arm64`) |
| Terraform CLI | `1.16.5` |
| Provider | `hashicorp/aws` (`~> 6.0`; selected version recorded in `.terraform.lock.hcl`) |
| AWS-compatible environment | Local floci |
| S3 endpoint | `http://localhost:4566` |
| AWS region | `us-east-1` |
| Terraform directory | `week9/day4/` |
| Temporary bucket | `cloudlab-week9-day4-99f39978` |

The lab used a **separate Day 4 local state**, and did not modify previously created Week 7 or Week 8 buckets.

## Configuration files

- `versions.tf`: Terraform and provider version requirements.
- `provider.tf`: AWS provider configured for floci S3, with path-style requests.
- `variables.tf`: project name and validated eight-character bucket suffix.
- `main.tf`: one tagged `aws_s3_bucket.day4` resource.
- `outputs.tf`: bucket name and ARN.
- `.gitignore`: excludes provider downloads, local state, state backups, and plan files.
- `.terraform.lock.hcl`: locks the selected provider version and checksum information; commit this file.

The bucket name is formed from a project name and unique suffix. During this lab the suffix was `99f39978`, supplied using `TF_VAR_bucket_suffix`.

```bash
export TF_VAR_bucket_suffix=99f39978
terraform init
terraform fmt
terraform validate
terraform plan
```

`terraform validate` succeeded. Initial plan: **1 to add, 0 to change, 0 to destroy**.

> Reuse note: if using this directory in a fresh terminal, set `TF_VAR_bucket_suffix` again (or provide `-var`) before running plans. The bucket was deliberately deleted during the exercise; running `terraform apply` now would recreate it.

## Lab 1 — Create and inspect state

```bash
terraform apply
terraform state list
terraform state show aws_s3_bucket.day4
terraform output
aws s3api head-bucket \
  --bucket cloudlab-week9-day4-99f39978 \
  --endpoint-url http://localhost:4566 \
  --no-cli-pager
terraform plan
```

Observed:

- Apply: **1 added, 0 changed, 0 destroyed**.
- `terraform state list`: `aws_s3_bucket.day4`.
- Bucket ARN: `arn:aws:s3:::cloudlab-week9-day4-99f39978`.
- `head-bucket`: `BucketRegion` was `us-east-1`, exit code `0`.
- Subsequent `terraform plan`: **No changes**.
- The state recorded provider-returned attributes such as bucket ID, ARN, region, encryption, versioning, and tags.

## Lab 2 — Simulate infrastructure drift

The isolated Day 4 bucket was deleted **outside Terraform** using AWS CLI. The `.tf` resource declaration remained unchanged.

```bash
aws s3api delete-bucket \
  --bucket cloudlab-week9-day4-99f39978 \
  --endpoint-url http://localhost:4566 \
  --no-cli-pager

terraform state list
terraform plan
```

The stored state continued to list `aws_s3_bucket.day4` before the refresh-only apply, although the bucket had been removed from floci.

The normal plan detected:

```text
Note: Objects have changed outside of Terraform
# aws_s3_bucket.day4 has been deleted
Plan: 1 to add, 0 to change, 0 to destroy.
```

**Lesson:** A normal plan refreshes its view of managed infrastructure and proposes changes to bring real resources back into alignment with configuration. Merely running `terraform plan` does not recreate resources or persist the refreshed view as the new state.

## Lab 3 — Inspect and apply refresh-only state changes

```bash
terraform plan -refresh-only
terraform state list
terraform apply -refresh-only --auto-approve
terraform state list
terraform output
terraform plan
```

The refresh-only plan reported the external deletion and proposed updating **recorded state and outputs only**, without changing remote infrastructure.

The refresh-only apply reported:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

bucket_arn = null
bucket_name = null
```

Following that operation:

- `terraform state list`: no managed resources.
- `terraform output`: both outputs were `null`.
- Normal `terraform plan`: **1 to add, 0 to change, 0 to destroy**, since `main.tf` still declares the missing bucket.

**Lesson:** Refresh-only reconciles Terraform's recorded knowledge with reality; it does not change the desired configuration. If the resource should permanently cease to be managed or created, that decision must also be reflected appropriately in configuration, with a careful review of any state implications.

> Safety note: `--auto-approve` was used in this isolated exercise. Review and approve state changes carefully in production; refresh-only applies change state, even though they do not change cloud resources.

## Final verification and cleanup

```bash
terraform state list
aws s3api head-bucket \
  --bucket cloudlab-week9-day4-99f39978 \
  --endpoint-url http://localhost:4566 \
  --no-cli-pager
echo "Head-bucket exit code: $?"
```

Observed final result:

- Empty Terraform resource list.
- `head-bucket` returned **HTTP 404 Not Found** with AWS CLI exit code **254**, confirming the temporary bucket is absent in this floci environment.
- No lab resource remained to destroy. Local `.tfstate` and `.tfstate.backup` files remain on disk but are ignored by Git.

Git ignore checks:

```bash
git check-ignore week9/day4/terraform.tfstate
git check-ignore week9/day4/terraform.tfstate.backup
git check-ignore week9/day4/.terraform/
```

All three paths were confirmed ignored.

## Production engineering concepts

### Configuration, state, and actual resources

- **Configuration (`.tf`)**: intended infrastructure.
- **State (`terraform.tfstate`)**: Terraform's saved mapping from resource addresses to remote objects and recorded attributes.
- **Actual infrastructure**: objects that currently exist in the provider.

External changes can cause infrastructure drift. Investigate the origin and impact of a change before restoring infrastructure or accepting new state.

### Local state versus remote state

Local state works for isolated exercises but is difficult to coordinate across engineers. Shared remote backends support common state storage and can provide additional capabilities, depending on the backend.

### State locking

State locking helps prevent concurrent operations from modifying the same Terraform state. It is **not** supplied by `.terraform.lock.hcl`; support depends on the backend. For an S3 backend, an appropriately configured lockfile can provide locking (for example, `use_lockfile = true`).

### State security

Terraform state can contain sensitive information. Keep state and backups out of public Git repositories. Protect remote state with suitable access controls, encryption, and recovery policies.

### Dependency lock file versus state file

| File | Role | Commit? |
|---|---|---|
| `.terraform.lock.hcl` | Selected provider versions and checksums | Yes |
| `terraform.tfstate` | Managed resource mappings, attributes, and outputs | No |

## Knowledge checks — passed

1. **Why state is needed:** Terraform maps declared resources to real objects and tracks provider-reported attributes.
2. **State list versus output:** `terraform state list` displays tracked resource addresses; `terraform output` displays root-module output values.
3. **Before refreshing, does state still list an externally deleted bucket?** Yes; the saved state can be stale.
4. **Does `terraform plan` recreate the bucket?** No; applying an approved normal plan is needed.
5. **Refresh-only versus normal plan:** normal plans propose infrastructure reconciliation; refresh-only plans propose state/output reconciliation.
6. **Does refresh-only apply recreate a missing resource?** No; it records the deletion in state.
7. **Production incident response:** investigate unplanned deletions, assess impact and recoverability, and follow an approved restoration or configuration-change path.
8. **Local versus remote state:** shared state helps team coordination; appropriate locking is separately necessary.
9. **Locking:** dependency lock files do not lock Terraform state; backends need actual state-locking support.
10. **Secrets:** state may contain sensitive attributes and should not be committed publicly.

## Outcome

Completed Terraform state inspection, baseline reconciliation, externally induced drift detection, normal-versus-refresh-only plan comparison, refresh-only state reconciliation, and verified cleanup in an isolated local floci environment.

**Lab status:** Practical exercises and knowledge assessment completed; GitHub commit/push is the final evidence step.
