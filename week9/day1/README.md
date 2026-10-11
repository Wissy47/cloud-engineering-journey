# Infrastructure as Code & Terraform Fundamentals

## 1. Objectives

- Explain Infrastructure as Code (IaC) and the operational problems it solves.
- Compare imperative AWS CLI operations with declarative Terraform configuration.
- Understand Terraform Core, providers, HCL resources, outputs, and state.
- Install and verify Terraform on an Apple Silicon Mac.
- Configure the AWS provider for a **pre-existing** floci instance.
- Initialize, validate, plan, apply, inspect, and safely destroy a temporary resource.
- Demonstrate idempotency and distinguish desired configuration from managed state.
- Document troubleshooting and protect state files from Git commits.

## 2. Environment

| Component | Verified setup |
|---|---|
| Host | Apple Silicon M1 Mac, macOS 26.1 |
| Terraform CLI | v1.16.5 (`darwin_arm64`) |
| AWS provider | `hashicorp/aws` v6.68.0 |
| AWS CLI region | `us-east-1` |
| Local AWS emulator | Existing `floci` Docker container |
| Local endpoint | `http://localhost:4566` |
| Repository | [cloud-engineering-journey](https://github.com/Wissy47/cloud-engineering-journey) |
| Lab directory | `week9/day1/` |

The existing `floci` container was confirmed **running** and **healthy**, without creating or replacing the control-plane container. An AWS CLI S3 `list-buckets` request succeeded and returned **four existing buckets**, belonging to earlier labs. They were not included in this Terraform state or destruction plan.

### Local AWS CLI environment

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_EC2_METADATA_DISABLED=true

aws s3api list-buckets --endpoint-url http://localhost:4566
```

The credentials above are dummy credentials for the local emulator, **not production AWS credentials**.

## 3. Concepts Learned

### Infrastructure as Code

IaC defines infrastructure in version-controlled configuration rather than relying on a sequence of manual console actions or commands. This improves repeatability, collaboration, reviews, and recovery, but configuration changes must still be reviewed carefully.

### Imperative vs. declarative

**Imperative AWS CLI:** ask the API to perform an operation:

```bash
aws s3api create-bucket \
  --bucket example-bucket \
  --endpoint-url http://localhost:4566
```

**Declarative Terraform:** declare that a resource should exist:

```hcl
resource "aws_s3_bucket" "day1" {
  bucket = "week9-day1-tf-20261011-2a287f5f"
}
```

Terraform calculates a plan from the configuration, the tracked state, and information read through the provider.

### Terraform architecture

1. **Terraform Core** loads configuration, resolves dependencies, calculates plans, and handles state.
2. **Provider plugins** implement resource operations against external APIs; this lab used the AWS provider.
3. **HCL (`.tf`)** defines the desired resources and configuration.
4. **Terraform state** maps resource addresses (for example, `aws_s3_bucket.day1`) to remote object identifiers and stores observed attributes.

### Desired state, actual resources, and state

| Item | Lab example |
|---|---|
| Desired configuration | `main.tf` declares one S3 bucket |
| Terraform resource address | `aws_s3_bucket.day1` |
| Actual bucket identifier | `week9-day1-tf-20261011-2a287f5f` |
| Local state | `terraform.tfstate` (never committed) |

A resource address identifies a managed object **within Terraform**; the bucket name identifies it through the **S3 API**. Losing state does not delete the bucket: it can cause Terraform to propose creating a duplicate or require recovery/import.

### Idempotency and drift

Once Terraform successfully created the bucket, a subsequent `terraform plan` returned **no changes**. This demonstrated reconciliation when configuration and observed infrastructure were consistent. Drift arises when managed infrastructure is changed outside Terraform; drift detection depends on what the provider can read.

## 4. Project Files

```text
week9/day1/
├── .gitignore
├── .terraform.lock.hcl
├── README.md
├── main.tf
├── outputs.tf
├── provider.tf
└── versions.tf
```

`.terraform/`, `terraform.tfstate`, and state backups may exist locally but must be ignored by Git.

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

- `required_version` constrains the Terraform **CLI** version.
- `source` identifies the AWS provider.
- `~> 6.0` permits compatible provider 6.x releases.
- `.terraform.lock.hcl` selected AWS provider **v6.68.0** for this lab, enabling reproducible provider selection.

### `provider.tf`

```hcl
provider "aws" {
  region = "us-east-1"

  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  s3_use_path_style = true

  endpoints {
    s3 = "http://localhost:4566"
  }
}
```

| Provider option | Reason for local training |
|---|---|
| `region` | Match the lab region |
| `access_key`, `secret_key` | Local emulator's non-production dummy credentials |
| `skip_credentials_validation` | Skip unnecessary real-AWS credential validation |
| `skip_metadata_api_check` | Avoid EC2 instance metadata discovery |
| `skip_requesting_account_id` | Avoid unnecessary AWS account-ID discovery |
| `s3_use_path_style` | Use path-style bucket URLs for the local endpoint |
| `endpoints.s3` | Route **S3** API calls to floci at `localhost:4566` |

**Safety:** This configuration is **only for local floci exercises**. The S3 override does not redirect every AWS service. Never reuse skipped validation/dummy credentials indiscriminately in production or add other service resources without checking endpoint configuration.

### `main.tf`

```hcl
resource "aws_s3_bucket" "day1" {
  bucket = "week9-day1-tf-20261011-2a287f5f"
}
```

This is the lab's **original temporary bucket name**, not a permanent bucket. Since cleanup succeeded, an ordinary `terraform plan` now proposes creating it again. Do not run `terraform apply` in this directory unless you intend to recreate the temporary resource.

### `outputs.tf`

```hcl
output "bucket_name" {
  description = "Name of the Terraform Day 1 S3 bucket"
  value       = aws_s3_bucket.day1.bucket
}

output "bucket_arn" {
  description = "ARN of the Terraform Day 1 S3 bucket"
  value       = aws_s3_bucket.day1.arn
}
```

These outputs demonstrate **resource references**. After destruction, the values are no longer present in current state, even though their definitions remain in the configuration.

### `.gitignore`

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
tfplan
*.tfplan.json
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
crash.log
crash.*.log
.terraformrc
terraform.rc
```

**Commit:** `.tf` files, `README.md`, `.gitignore`, and `.terraform.lock.hcl` (after reviewing staged contents).  
**Do not commit:** `.terraform/`, state files/backups, saved plans, or secrets. A `.tf` file containing actual secrets is also unsafe to publish even if the file type is normally tracked.

## 5. Commands and Practical Results

### A. Installation and verification

Homebrew initially failed due to an **Intel/Rosetta process attempting to use the ARM Homebrew prefix**, followed by an **outdated Xcode Command Line Tools** error (installed CLT 15.3 on macOS 26.1).

The official standalone macOS ARM64 Terraform 1.16.5 archive was downloaded and its SHA-256 checksum verified. Terraform was installed in `~/.local/bin/terraform` and added to `PATH`.

Verified result:

```text
Terraform v1.16.5
on darwin_arm64
/Users/wissy47/.local/bin/terraform: Mach-O 64-bit executable arm64
```

The earlier shell reported `uname -m` as `x86_64` and `arch` as `i386`, consistent with a Rosetta shell; the Terraform binary itself was verified as ARM64. Terminal architecture remediation was not part of the completed lab.

### B. Infrastructure workflow

Executed from `week9/day1`:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform state list
terraform state show aws_s3_bucket.day1
terraform output
terraform plan
terraform plan -destroy
terraform destroy
```

Actual observations:

| Checkpoint | Verified result |
|---|---|
| `terraform init` | Successfully initialized; AWS provider v6.68.0 |
| `terraform validate` | `Success! The configuration is valid.` |
| First `terraform plan` | **1 to add, 0 to change, 0 to destroy** |
| `terraform apply` | Bucket existed and was tracked (confirmed by subsequent checks) |
| S3 `head-bucket` | Returned `BucketRegion: us-east-1`; exit code **0** |
| `terraform state list` | `aws_s3_bucket.day1` |
| `terraform state show` | Confirmed bucket ID, ARN, region, and attributes |
| Subsequent `terraform plan` | **No changes** |
| `terraform output` | Printed bucket name and ARN |
| `terraform plan -destroy` | **0 to add, 0 to change, 1 to destroy** |
| `terraform destroy` | **Destroy complete! Resources: 1 destroyed.** |
| Post-destroy `terraform state list` | No resources listed |
| Post-destroy S3 `head-bucket` | **404 Not Found**, expected after deletion |
| Post-destroy `terraform plan` | **1 to add, 0 to change, 0 to destroy**, because `main.tf` still declares the bucket |

### C. State details observed

```text
Resource address: aws_s3_bucket.day1
Bucket ID:        week9-day1-tf-20261011-2a287f5f
ARN:              arn:aws:s3:::week9-day1-tf-20261011-2a287f5f
Bucket region:    us-east-1
force_destroy:    false
versioning:       false
```

The provider also reported default `AES256` encryption. This is an **emulator/provider observation**, not proof that every real AWS storage behavior is implemented identically in floci.

## 6. Safe Cleanup and Why the Next Plan Creates Again

The destroy plan targeted only `aws_s3_bucket.day1`; none of the four previously existing S3 buckets appeared in it. Destruction was confirmed by the Terraform completion message, empty state listing, and S3 HTTP 404.

Terraform still reads `main.tf` afterward. Since configuration declares a bucket but the resource no longer exists, the next plan proposes **one creation**. **No apply should be run accidentally after this point.**

The cleanup demonstrated that destroying a resource is distinct from editing configuration or deleting state.

## 7. Troubleshooting Log

| Issue | Cause | Resolution / lesson |
|---|---|---|
| Homebrew Rosetta error | Intel process with ARM Homebrew prefix | Used `arch -arm64` for the Homebrew attempt |
| `brew tap` invalid option | Multiple commands accidentally combined on one line | Execute commands separately |
| Homebrew rejected Command Line Tools | Installed CLT 15.3 was too old | Used official standalone ARM64 Terraform binary, without deleting existing CLT |
| `terraform` initially not found | Executable not yet installed | Installed into `~/.local/bin` and updated `PATH` |
| Post-destroy `head-bucket` returned 404 | Temporary bucket had been destroyed | Expected and useful cleanup verification |
| Post-destroy plan proposed +1 | Desired configuration still declares bucket | Expected; plan is not an apply |

## 8. State Security and Operational Lessons

1. State maintains a mapping between HCL resource addresses and real infrastructure IDs, along with observed attributes.
2. State **can contain sensitive information** even if output is marked sensitive.
3. Never commit local state, state backups, saved plans, or real credentials to Git.
4. If state is lost, the actual resource may remain; restore state safely or import resources rather than blindly re-applying.
5. Always review destructive plans; a successful `terraform validate` does **not** guarantee a safe plan.
6. Provider locks improve repeatability; `.terraform.lock.hcl` does **not** lock the Terraform CLI version.
7. The floci endpoint must be configured for every AWS service being used; the S3 endpoint override is not a universal redirect.
8. AWS-compatible emulators can diverge from actual AWS behavior; investigate API-level compatibility when errors occur.

## 9. Knowledge Check

**Result: 3/3 — passed.**

- **Why did the second plan show no changes?** Terraform had tracked the created bucket, and the observed resource matched the declared configuration.
- **What differs between `aws_s3_bucket.day1` and the bucket name?** The first is Terraform's resource address; the second is the actual S3 name/ID.
- **What if `terraform.tfstate` is deleted while a bucket remains?** Terraform loses the existing mapping and may try to create a duplicate, causing conflicts or requiring state recovery/import.

## 10. GitHub and Dashboard Evidence

- **Day 1 README:** [week9/day1/README.md](https://github.com/Wissy47/cloud-engineering-journey/blob/main/week9/day1/README.md) *(link becomes available after push)*
- **Practical evidence:** Terminal output from Terraform initialization, validation, plan, state inspection, AWS CLI verification, outputs, destroy, and post-destroy plan.
- **Dashboard Evidence area:** Add the README link after the GitHub push is verified.

