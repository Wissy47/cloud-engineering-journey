# Week 9 — Day 3: Terraform Resource Dependencies

## Objectives

- Understand implicit dependencies created through resource references.
- Understand explicit dependencies with `depends_on` and when they are necessary.
- Inspect Terraform's dependency graph.
- Create a temporary VPC and subnet in floci with Terraform.
- Verify resource associations and state, test a no-change plan, and safely destroy resources in reverse dependency order.

## Lab environment

| Component | Configuration |
|---|---|
| Host | Apple Silicon M1, macOS |
| Terraform CLI | 1.16.5 (`darwin_arm64`) |
| Provider | `hashicorp/aws` 6.x (verify exact Day 3 selection in `.terraform.lock.hcl`) |
| AWS-compatible service | floci, existing container |
| API endpoint | `http://localhost:4566` (`ec2` provider endpoint) |
| Region | `us-east-1` |
| Lab folder | `week9/day3/` |

Only the temporary Day 3 VPC and subnet were managed by this Terraform state. Earlier training resources were not targeted.

## Project files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform CLI and AWS provider constraints |
| `provider.tf` | Dummy local credentials and the floci EC2 API endpoint |
| `variables.tf` | Project name and lab CIDR parameters |
| `main.tf` | VPC and subnet declarations with a reference-based dependency |
| `outputs.tf` | VPC ID, subnet ID, and the subnet's VPC ID |
| `.terraform.lock.hcl` | Selected provider dependency/checksums; commit this file |
| `.gitignore` | Excludes local state, downloaded providers, plan files, and variable files |

## Infrastructure configuration

The VPC was declared with CIDR `10.90.0.0/16`. The subnet was declared with CIDR `10.90.1.0/24` in `us-east-1a`.

The key expression was:

```hcl
resource "aws_subnet" "day3_subnet" {
  vpc_id            = aws_vpc.day3.id
  cidr_block        = var.subnet_cidr
  availability_zone = "us-east-1a"
}
```

`aws_vpc.day3.id` is a **resource attribute reference**, not an input variable. It creates an **implicit dependency**: the VPC must be created before the subnet can be created. An additional `depends_on = [aws_vpc.day3]` would be redundant. Explicit `depends_on` is useful when Terraform cannot infer an operational prerequisite from references.

The subnet block's textual position in `main.tf` does not control creation order; Terraform uses its dependency graph.

## Commands used

```bash
# Check the existing VPC CIDRs before choosing the lab range
aws ec2 describe-vpcs \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock}' \
  --output table

# Initialize and review configuration
terraform init
terraform fmt
terraform validate
terraform plan
terraform graph

# Create and inspect (performed during lab)
terraform apply
terraform output
terraform state list
terraform state show aws_vpc.day3
terraform state show aws_subnet.day3_subnet

# Verify in floci
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --output table
aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" --output table

# Check reconciliation and review destruction
terraform plan
terraform plan -destroy
terraform destroy
terraform state list
terraform plan
```

For the AWS CLI commands, the session used environment variables targeting floci (`AWS_ENDPOINT_URL=http://localhost:4566`, region `us-east-1`, and dummy `test` credentials). On systems where those variables are absent, supply `--endpoint-url http://localhost:4566` explicitly.

## Actual lab evidence and results

### Before creation

The existing VPC CIDRs included `10.9.0.0/16`, `10.99.0.0/16`, `10.40.0.0/16`, and `172.31.0.0/16`. The chosen `10.90.0.0/16` lab network did not overlap those ranges.

Initial Terraform plan:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

The generated dependency graph contained:

```dot
"aws_subnet.day3_subnet" -> "aws_vpc.day3";
```

This arrow means **the subnet depends on the VPC**; it is not an indication that the subnet is created first.

### After apply

| Resource/attribute | Verified value |
|---|---|
| VPC resource address | `aws_vpc.day3` |
| VPC ID | `vpc-bf35fefb` |
| VPC CIDR | `10.90.0.0/16` |
| Subnet resource address | `aws_subnet.day3_subnet` |
| Subnet ID | `subnet-fd4f9be6` |
| Subnet CIDR | `10.90.1.0/24` |
| Availability zone | `us-east-1a` |
| Subnet's VPC ID | `vpc-bf35fefb` |

`terraform state list` showed both resources, and `terraform output` confirmed that `vpc_id` matched `subnet_vpc_id`. An independent AWS CLI lookup also verified the VPC. The regular post-apply plan reported:

```text
No changes. Your infrastructure matches the configuration.
```

### Destruction and verification

The destruction plan showed exactly the two temporary resources:

```text
Plan: 0 to add, 0 to change, 2 to destroy.
```

Execution logs proved reverse dependency order:

```text
aws_subnet.day3_subnet: Destroying... [id=subnet-fd4f9be6]
aws_subnet.day3_subnet: Destruction complete after 0s
aws_vpc.day3: Destroying... [id=vpc-bf35fefb]
aws_vpc.day3: Destruction complete after 0s
Destroy complete! Resources: 2 destroyed.
```

Afterward, `terraform state list` was empty. The floci subnet lookup returned `{"Subnets": []}` with exit code `0`; the VPC lookup returned `InvalidVpcID.NotFound` with exit code `254`. These are the **observed floci API responses**, and both support the conclusion that the temporary resources were gone.

The final plan showed:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

This is expected because the `.tf` configuration still declares both resources even though Terraform destroyed them. **Do not apply this final plan** unless intentionally recreating the lab.

## State and Git safety

- Keep `.terraform.lock.hcl` in version control for provider reproducibility.
- Do **not** commit `.terraform/`, `terraform.tfstate`, or `terraform.tfstate.backup`.
- State can contain sensitive data; inspect staged files before pushing.
- Platform-created VPC defaults (route table, security group, and network ACL) appeared as attributes of the VPC, not independently declared managed resources.
- A destructive plan must be reviewed before approval.

Suggested staging verification:

```bash
cd ~/cloud-engineering-journey
git add week9/day3/
git -c core.pager=cat diff --cached --name-only
git diff --cached --check
```

## Knowledge check — passed (5/5)

1. **Creation order:** The subnet's `vpc_id` references the VPC, so Terraform provisions the dependency first.
2. **Implicit vs explicit:** References create implicit dependencies; `depends_on` declares hidden operational dependencies when necessary.
3. **Why not hardcode IDs:** Resource references adapt to newly created resource identifiers, making configuration reusable.
4. **Destroy order:** Dependents (subnet) are removed before their dependency (VPC).
5. **Default VPC components:** AWS/floci creates certain VPC defaults automatically; they do not appear as independently managed Terraform resources unless declared or otherwise managed.

## Lessons learned

Terraform's dependency graph controls execution more reliably than manually sequencing API calls. References both pass resource data and communicate dependency edges. Destroying a dependent resource before its parent protects referential integrity. Terraform state records managed objects, while configuration continues to express desired infrastructure even after destruction.

## Evidence

- [Day 3 Terraform configuration and README](https://github.com/Wissy47/cloud-engineering-journey/tree/main/week9/day3) 
