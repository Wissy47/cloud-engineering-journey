# Week 9 — Day 5: Terraform Modules & Reusable Infrastructure

## Objectives

- Understand root modules and child modules.
- Build a reusable Terraform S3 child module.
- Pass input variables and tags from the root module.
- Expose child module outputs to the root module.
- Reuse one module to provision multiple S3 buckets.
- Understand module resource addresses and shared state.
- Verify idempotency and safely destroy temporary resources.

## Lab Environment

| Component | Configuration |
|---|---|
| Machine | Apple Silicon Mac |
| Terraform | v1.16.5 |
| AWS provider | v6.69.1 |
| AWS-compatible environment | floci |
| S3 endpoint | `http://localhost:4566` |
| Region | `us-east-1` |
| Lab directory | `week9/day5/` |

## Project Structure

```text
day5/
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── .terraform.lock.hcl
├── .gitignore
└── modules/
    └── s3/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Reusable S3 Module

The child module defines an S3 bucket using inputs supplied by the caller.

**`modules/s3/main.tf`**

```hcl
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}
```

Its inputs are defined in `modules/s3/variables.tf`, and its outputs expose the bucket ID and ARN.

```hcl
output "bucket_id" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
```

## Calling the Module

The root configuration invokes the same child module twice:

- `module.storage` — Primary storage bucket.
- `module.backups` — Backup bucket.

Both module calls use `source = "./modules/s3"` with different bucket names and tags.

## Infrastructure Created

| Module | Terraform resource address | Bucket name |
|---|---|---|
| Storage | `module.storage.aws_s3_bucket.this` | `cloudlab-week9-day5-e77b19cc` |
| Backups | `module.backups.aws_s3_bucket.this` | `cloudlab-week9-day5-backups-e77b19cc` |

Both buckets were created in the local floci S3 environment.

## Terraform Verification

Commands executed:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform state list
terraform output
```

The configuration passed validation.

After deploying both module instances, `terraform state list` returned:

```text
module.backups.aws_s3_bucket.this
module.storage.aws_s3_bucket.this
```

A subsequent `terraform plan` reported:

```text
No changes. Your infrastructure matches the configuration.
```

This demonstrated idempotency.

## Independent AWS CLI Verification

Both buckets were verified through the local floci S3 endpoint using `aws s3api head-bucket`.

Both checks returned exit code `0` before cleanup.

## Cleanup

Executed:

```bash
terraform plan -destroy
terraform destroy
```

The destruction plan contained:

```text
Plan: 0 to add, 0 to change, 2 to destroy.
```

Terraform successfully deleted both buckets.

Verification after destruction:

- `terraform state list` returned no managed resources.
- Both S3 `head-bucket` requests returned HTTP 404.
- The subsequent `terraform plan` proposed `2 to add, 0 to change, 0 to destroy`, confirming that the module configuration remained reusable.

No earlier lab resources were targeted.

## Key Lessons Learned

1. A Terraform root module is the top-level configuration used to run Terraform operations.
2. Child modules encapsulate reusable infrastructure configuration.
3. Input variables let module callers customize resources.
4. Output blocks expose resource attributes to calling modules.
5. Module instance names distinguish resources created from the same source module.
6. Multiple child modules within one root configuration share the root's Terraform state.
7. Production and development environments should use appropriately isolated state boundaries.
8. Renaming a managed module may require a `moved` block or state migration.
9. Routine changes should be made through Terraform configuration rather than repeated use of targeted destruction.

## Knowledge Check

Completed all Day 5 knowledge checks, including a final correction demonstrating understanding of separate state boundaries for development and production.

