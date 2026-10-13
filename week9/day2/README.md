# Week 9 — Day 2: Terraform Variables, Locals, References & Outputs

## Objectives

- Make Terraform configurations reusable using typed input variables, defaults, and validation.
- Build resource names from local expressions instead of hardcoded strings.
- Reference Terraform resources and expose their attributes through outputs.
- Understand how CLI variable overrides affect a Terraform plan.
- Recognize when an attribute change forces resource replacement.
- Understand why development, staging, and production need independent state boundaries.
- Safely create, inspect, and destroy a temporary S3 bucket against the existing floci instance.

## Lab environment

| Component | Value |
|---|---|
| Host | Apple Silicon M1 Mac, macOS 26.1 |
| Terraform CLI | v1.16.5 (`darwin_arm64`), verified in Day 1 |
| AWS provider | `hashicorp/aws` v6.68.0 |
| AWS region | `us-east-1` |
| Emulator | Existing `floci` container |
| Local S3 endpoint | `http://localhost:4566` |
| Repository folder | `week9/day2/` |
| Temporary bucket | `cloudlab-dev-w9d2-8204531d` (destroyed at end of lab) |

The existing floci control-plane instance was used; no new instance was started. Earlier-week resources were not included in the Terraform destruction plan.

## Concepts learned

### Inputs, locals, and outputs

- **Input variables** accept external values, such as project name, environment, and a bucket suffix. Values can come from defaults, `TF_VAR_...` environment variables, or command-line `-var` arguments.
- **Locals** compute reusable values inside a configuration. They are not directly overridable inputs.
- **Resource references** let one expression use attributes from a managed object, for example `aws_s3_bucket.day2.arn`.
- **Outputs** expose selected evaluated results from Terraform state for operators or automation.

### State and replacement

The same resource address in the same state file does not represent independent environments just because `var.environment` changes. In this lab, a staging override changed the computed bucket name, which is not renameable in place. Terraform therefore proposed replacing the existing development bucket. The plan was **not applied**.

Separate state boundaries are needed for independently managed environments; production also calls for separate access controls and safety checks.

## Files

| File | Responsibility |
|---|---|
| `versions.tf` | Terraform CLI and AWS provider version constraints |
| `provider.tf` | AWS provider targeting floci's local S3 endpoint |
| `variables.tf` | Typed variables, defaults, required suffix, and environment validation |
| `locals.tf` | Reusable computed naming expressions |
| `main.tf` | Terraform-managed S3 bucket declaration |
| `outputs.tf` | Bucket name, ARN, environment, and name-prefix outputs |
| `.terraform.lock.hcl` | Locked provider selection and checksums; committed |
| `.gitignore` | Prevents state, provider downloads, variable files, and plans from being committed |

### Key configuration examples

**`variables.tf`** (relevant parts):

```hcl
variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "cloudlab"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "bucket_suffix" {
  description = "Unique suffix for the S3 bucket"
  type        = string
}
```

**`locals.tf`:**

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  bucket_name = "${local.name_prefix}-w9d2-${var.bucket_suffix}"
}
```

**`main.tf`:**

```hcl
resource "aws_s3_bucket" "day2" {
  bucket = local.bucket_name
}
```

**`outputs.tf`:**

```hcl
output "bucket_name" {
  description = "Name of the Day 2 S3 bucket"
  value       = aws_s3_bucket.day2.bucket
}

output "bucket_arn" {
  description = "ARN of the Day 2 S3 bucket"
  value       = aws_s3_bucket.day2.arn
}

output "deployment_environment" {
  description = "Environment used for this deployment"
  value       = var.environment
}

output "name_prefix" {
  description = "Computed resource naming prefix"
  value       = local.name_prefix
}
```

The repository's `.tf` files are the authoritative complete configuration; the blocks above highlight Day 2 concepts.

## Commands used

```bash
cd ~/cloud-engineering-journey/week9/day2

# Local emulator inputs (dummy credentials only)
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_EC2_METADATA_DISABLED=true

# Lab-specific inputs; keep the suffix stable for the entire lifecycle
export TF_VAR_project_name=cloudlab
export TF_VAR_environment=dev
export TF_VAR_bucket_suffix=8204531d

terraform init
terraform fmt
terraform validate
terraform plan

# Invalid value test: expected validation failure, no infrastructure change
terraform plan -var="environment=testing"

# Approved create plan
terraform apply
terraform state list
terraform output
terraform output -raw bucket_name

# Non-destructive replacement preview; NOT applied
terraform plan -var="environment=staging"
terraform plan

# Cleanup
terraform plan -destroy
terraform destroy
terraform state list
terraform plan
```

## Practical results and evidence

### 1. Initialization and validation

- `terraform init` successfully installed `hashicorp/aws v6.68.0` and created `.terraform.lock.hcl`.
- `terraform validate` reported **Success! The configuration is valid.**
- The initial plan proposed **1 to add, 0 to change, 0 to destroy** for `aws_s3_bucket.day2`.
- Terraform evaluated variables and locals into `cloudlab-dev-w9d2-8204531d`.

### 2. Input validation

Running `terraform plan -var="environment=testing"` failed with:

```text
Error: Invalid value for variable
var.environment is "testing"
Environment must be dev, staging, or prod.
```

The invalid input was rejected before any infrastructure changes.

### 3. Creation and state

The approved `terraform apply` returned:

```text
aws_s3_bucket.day2: Creation complete after 1s [id=cloudlab-dev-w9d2-8204531d]
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

`terraform state list` returned `aws_s3_bucket.day2`.

### 4. Troubleshooting: no outputs found

Initially, `terraform output` warned **No outputs found**. Investigation showed:

```text
cat: outputs.tf: No such file or directory
```

The resource itself existed and a normal plan showed no infrastructure changes. The fix was to add `outputs.tf`, review an **outputs-only** plan, and apply it. Terraform then reported:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The following values were confirmed:

```text
bucket_arn = "arn:aws:s3:::cloudlab-dev-w9d2-8204531d"
bucket_name = "cloudlab-dev-w9d2-8204531d"
deployment_environment = "dev"
name_prefix = "cloudlab-dev"
```

`terraform output -raw bucket_name` printed the bucket name without a newline; the terminal's trailing `%` indicator was from Zsh, not part of the bucket name.

### 5. Variable override and forced replacement

Running `terraform plan -var="environment=staging"` produced:

```text
# aws_s3_bucket.day2 must be replaced
-/+ destroy and then create replacement
bucket = "cloudlab-dev-w9d2-8204531d" -> "cloudlab-staging-w9d2-8204531d" # forces replacement
Plan: 1 to add, 0 to change, 1 to destroy.
```

This replacement plan was **not applied**. The following plain `terraform plan` reported **No changes. Your infrastructure matches the configuration.** It confirmed the original dev inputs still matched the deployed resource.

### 6. Destruction and post-destroy reconciliation

- `terraform plan -destroy` targeted only `aws_s3_bucket.day2`.
- `terraform destroy` reported **Destroy complete! Resources: 1 destroyed.**
- `terraform state list` produced no resource entries.
- A subsequent normal `terraform plan` proposed **1 to add, 0 to change, 0 to destroy**, since the resource declaration remained in `main.tf` while the resource was absent from state.
- **Independent S3 post-destroy `head-bucket` check:** not yet included in the shared output; complete and record the expected `404 Not Found` before closing documentation.

## Troubleshooting lessons

1. A successful resource apply does not imply root outputs exist; an `output` block must be configured and applied.
2. Shell expansion requires `$`: `echo TF_VAR_bucket_suffix` prints text, while `echo "$TF_VAR_bucket_suffix"` prints the value.
3. An invalid `-var` override is rejected by custom validation without modifying state.
4. A CLI override does not permanently alter `TF_VAR_...` environment variables.
5. A changed resource attribute may require replacement rather than an in-place update.
6. Planning alone is non-destructive; applying a replacement plan would have destroyed the existing dev bucket.
7. After destruction, configuration still expresses desired infrastructure, so a normal plan proposes recreation.

## State and Git security

- Commit `.terraform.lock.hcl` and reviewed `.tf` source files.
- Exclude `.terraform/`, `*.tfstate`, `*.tfstate.*`, saved plans, and secrets from version control.
- Use dummy credentials exclusively for floci; never store real AWS access keys in `provider.tf`.
- Review all destroy/replace actions before confirming `terraform apply` or `terraform destroy`.
- Avoid deleting or editing state manually to resolve mismatches.

## Knowledge check

**Result:** State isolation follow-up passed (2/2). The learner correctly explained that sharing one state boundary can cause a variable change to propose replacing an existing environment's bucket, and that independent environments require separate state boundaries. The initial answers were refined to distinguish *S3 bucket-name immutability* from *global naming uniqueness*.

## Conclusion

Day 2 demonstrated reusable naming through input variables and locals, resource attribute outputs, variable validation, command-line overrides, safe inspection of replacement plans, and successful cleanup of a temporary Terraform-managed S3 bucket. The next lesson is deliberately **not** included in this README.
