# Week 9 — Day 7: Terraform Infrastructure as Code Capstone

## Project Overview

Built reusable AWS-compatible infrastructure using Terraform child modules, deploying a VPC, a subnet, and an S3 artifact bucket in the local floci environment.

The project demonstrates modular architecture, dependency management, infrastructure validation, idempotency, and safe cleanup.

## Environment

| Component | Configuration |
|---|---|
| Terraform | v1.16.5 |
| AWS Provider | v6.69.1 |
| AWS-compatible emulator | floci |
| Region | us-east-1 |
| Environment | dev |
| Endpoint | http://localhost:4566 |
| Terraform state | Isolated Day 7 local state |

## Architecture

```text
Terraform Root Module (week9/day7)
│
├── Network Module (modules/network)
│   ├── VPC: 10.97.0.0/16
│   └── Subnet: 10.97.1.0/24
│       └── Availability Zone: us-east-1a
│
└── Storage Module (modules/storage)
    └── S3 Artifact Bucket
```

The subnet depends on the VPC through `aws_vpc.main.id`.

The S3 bucket is independent of the VPC and subnet.

Although configured to assign public IPs on launch, the subnet does not have an Internet Gateway and public default route, so it is not a fully internet-accessible public subnet.

## Project Structure

```text
day7/
├── versions.tf
├── provider.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── .gitignore
├── .terraform.lock.hcl
├── README.md
└── modules/
    ├── network/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── storage/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Infrastructure Provisioned

| Resource | Terraform address | Generated identifier |
|---|---|---|
| VPC | `module.network.aws_vpc.main` | `vpc-faf03e5d` |
| Subnet | `module.network.aws_subnet.public` | `subnet-ec5f58f6` |
| S3 bucket | `module.storage.aws_s3_bucket.artifacts` | `week9-capstone-dev-artifacts-de35c5c4` |

These identifiers are historical lab evidence. All three resources were destroyed after validation.

## Implementation

The network module accepts VPC CIDR, subnet CIDR, availability zone, project name, environment, and shared tags.

The storage module accepts a unique bucket name and shared tags.

The root module passes inputs to the child modules and exposes their outputs.

Common tags are defined with Terraform locals and applied using `merge()`.

## Deployment

Initialized and validated the configuration:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Deployed the network module first, then integrated and deployed the storage module.

The completed project contained three managed resources:

```text
module.network.aws_subnet.public
module.network.aws_vpc.main
module.storage.aws_s3_bucket.artifacts
```

## Independent Verification

Used the AWS CLI against floci to verify:

- VPC CIDR: `10.97.0.0/16`
- Subnet CIDR: `10.97.1.0/24`
- Subnet VPC ID matched `vpc-faf03e5d`
- Subnet Availability Zone: `us-east-1a`
- Subnet public IP mapping enabled
- Resource tags: `Environment`, `Project`, `ManagedBy`, and `Name`
- S3 bucket existed and had the expected tags

The final plan after deployment reported:

```text
No changes. Your infrastructure matches the configuration.
```

## Dependency and Failure Handling

The subnet references the VPC ID, creating an implicit dependency.

Terraform creates the VPC before the subnet and destroys the subnet before the VPC.

The S3 bucket has no dependency on the network resources.

Terraform does not guarantee automatic rollback of previously created resources if a later operation fails. Successfully created resources may remain and be tracked in state.

## Safe Cleanup

Reviewed the destruction plan:

```text
Plan: 0 to add, 0 to change, 3 to destroy.
```

Executed:

```bash
terraform destroy
terraform state list
```

Result:

```text
Destroy complete! Resources: 3 destroyed.
```

The Terraform state resource list was empty.

Independent AWS CLI verification confirmed:

- S3 bucket: HTTP 404
- VPC: `InvalidVpcID.NotFound`
- Subnet: Empty `Subnets` array in floci

The final Terraform plan reported:

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

This demonstrated that the configuration remained reusable after the resources were removed.

## Lessons Learned

1. Child modules provide reusable infrastructure components.
2. Terraform resource dependencies determine safe creation and destruction ordering.
3. Separate module instances in the same root module share a state boundary.
4. Root and child module inputs and outputs create clear module interfaces.
5. Centralized tags improve consistency.
6. Infrastructure must be independently verified using provider APIs.
7. An S3 bucket is not located inside a VPC simply because both are managed by the same Terraform project.
8. Terraform applies are not atomic transactions with guaranteed rollback.
9. Terraform plans must be reviewed before destructive actions.
10. Destroying infrastructure does not remove the Terraform source code.
