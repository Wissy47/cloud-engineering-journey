# Week 9 — Day 6: Terraform Lifecycle Management & Safe Infrastructure Changes

## Objectives

Understand how Terraform handles resource updates, replacements, lifecycle protections, infrastructure drift, and safe cleanup.

## Lab Environment

| Component | Details |
|---|---|
| Terraform | v1.16.5 |
| AWS Provider | v6.69.1 |
| Environment | floci (local AWS-compatible emulator) |
| Region | us-east-1 |
| S3 Endpoint | `http://localhost:4566` |
| Directory | `week9/day6` |

## Project Structure

```text
day6/
├── .terraform.lock.hcl
├── main.tf
├── provider.tf
├── variables.tf
├── versions.tf
└── README.md
```

## Infrastructure

Created one temporary S3 bucket:

`cloudlab-week9-day6-fcc103b5`

Terraform resource address:

`aws_s3_bucket.lifecycle_lab`

## Experiment 1 — In-Place Update

Changed the `Environment` tag from `lab` to `testing`.

Terraform proposed:

```text
~ update in-place

Plan: 0 to add, 1 to change, 0 to destroy.
```

After applying, AWS CLI verification confirmed that the updated tag was present without replacing the bucket.

**Lesson:** Some attributes, such as S3 bucket tags, can be updated without replacing infrastructure.

## Experiment 2 — Resource Replacement

Changed the configured S3 bucket name.

Terraform proposed:

```text
-/+ destroy and then create replacement

Plan: 1 to add, 0 to change, 1 to destroy.
```

The bucket attribute was marked `# forces replacement`.

The replacement was not applied.

**Lesson:** Changing attributes that cannot be modified in place can require replacing a resource.

## Experiment 3 — prevent_destroy

Configured:

```hcl
lifecycle {
  prevent_destroy = true
}
```

With the replacement still requested, Terraform returned:

```text
Error: Instance cannot be destroyed
```

**Lesson:** `prevent_destroy` rejects plans that require destruction while the protection remains in the resource configuration. It does not prevent out-of-band deletion.

## Experiment 4 — create_before_destroy

Configured:

```hcl
lifecycle {
  create_before_destroy = true
}
```

Terraform proposed:

```text
+/- create replacement and then destroy

Plan: 1 to add, 0 to change, 1 to destroy.
```

The plan was inspected but not applied.

**Lesson:** `create_before_destroy` changes replacement ordering. It does not eliminate resource deletion or guarantee zero downtime.

## Experiment 5 — ignore_changes

Configured:

```hcl
lifecycle {
  ignore_changes = [
    tags["Environment"]
  ]
}
```

Using AWS CLI, changed the bucket's `Environment` tag outside Terraform:

```text
testing -> production
```

Direct AWS CLI verification confirmed the external change.

However, Terraform reported:

```text
No changes. Your infrastructure matches the configuration.
```

**Lesson:** Terraform can ignore an attribute difference when planning updates, even when the actual infrastructure differs from the declared configuration.

## Experiment 6 — Drift Reconciliation

Removed the `ignore_changes` lifecycle block.

Terraform then proposed:

```text
~ "Environment" = "production" -> "testing"

Plan: 0 to add, 1 to change, 0 to destroy.
```

After applying, AWS CLI verification confirmed that `Environment` was restored to `testing`.

A subsequent Terraform plan reported no changes.

**Lesson:** Terraform reconciles detected infrastructure drift with the desired configuration when the relevant changes are not ignored.

## State Management Observation

After the external tag change, `terraform state show` initially continued displaying the previously saved value.

A subsequent Terraform plan read the actual value from floci and proposed reconciliation.

**Lesson:** Refreshing values during a normal plan does not necessarily persist them to the saved Terraform state.

## Troubleshooting

Resolved the following configuration errors during the lab:

- `Unsupported block type` — Corrected placement of the `lifecycle` block inside the resource.
- `Reference to undeclared resource` — Corrected `locals.bucket_name` to `local.bucket_name`.
- `Reference to undeclared local value` — Restored the missing local value declaration.

## Cleanup

Executed:

```bash
terraform plan -destroy
terraform destroy
```

Terraform confirmed:

```text
Destroy complete! Resources: 1 destroyed.
```

Verified that the bucket was absent using:

```bash
aws s3api head-bucket \
  --bucket cloudlab-week9-day6-fcc103b5 \
  --endpoint-url http://localhost:4566 \
  --no-cli-pager
```

The command returned HTTP 404.

A subsequent `terraform plan` proposed creating one bucket, confirming that the Terraform configuration remained reusable.

No earlier Cloud Engineering lab resources were included in the destruction plan.

## Key Takeaways

1. Always inspect Terraform execution plans before applying changes.
2. Distinguish in-place updates from resource replacements.
3. Use `prevent_destroy` as a protective safeguard, not as the only deletion control.
4. Use `create_before_destroy` only where temporary resource coexistence is supported.
5. Restrict `ignore_changes` to attributes intentionally managed outside Terraform.
6. Understand the difference between actual infrastructure, desired configuration, and saved Terraform state.
7. Verify infrastructure changes directly through the provider API.
8. Keep Terraform state files and provider working directories out of Git.
