# Week 11 — Day 1: IAM Least Privilege & Security Review

## Overview

Performed a read-only security review of existing IAM resources in the local floci AWS-compatible environment.

Inspected IAM users, roles, trust policies, managed policies, and permission scope. Designed a least-privilege S3 object-read policy and verified its intended structure using Python.

No existing infrastructure or IAM permissions were modified.

## Environment

| Component | Configuration |
|---|---|
| Computer | Apple Silicon M1 Mac |
| AWS-compatible environment | floci |
| AWS endpoint | http://localhost:4566 |
| AWS region | us-east-1 |
| Credentials | Local environment-based test credentials |
| Project | cloud-engineering-journey |

## Learning Objectives

- Explain IAM least privilege.
- Distinguish IAM users, roles, and temporary credentials.
- Understand trust policies versus permissions policies.
- Compare AWS managed and inline policies.
- Identify excessive permissions.
- Design an S3 policy scoped to one bucket.
- Validate policy structure without changing deployed resources.
- Understand IAM authorization and explicit Deny precedence.

## 1. Environment Verification

Commands:

```bash
cd ~/cloud-engineering-journey

docker ps --filter "ancestor=floci/floci:latest"

curl -sS -o /dev/null -w "HTTP %{http_code}\n" \
  http://localhost:4566

aws configure list
```

Observed results:

- Existing floci container was running and healthy.
- Local endpoint returned HTTP 200.
- Configured region was us-east-1.
- AWS CLI used local test credentials from environment variables.

## 2. IAM Identity Inventory

Commands:

```bash
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 iam list-users --output json

aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 iam list-roles \
  --query 'Roles[*].[RoleName,Arn]' --output table
```

Results:

- IAM users: 0
- IAM roles: 1
- Role name: CloudLabEC2Role
- Role ARN: arn:aws:iam::000000000000:role/CloudLabEC2Role

## 3. IAM Trust Policy

Command:

```bash
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 iam get-role \
  --role-name CloudLabEC2Role \
  --query 'Role.AssumeRolePolicyDocument' --output json
```

Verified trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

The trust policy determines who can assume the role.

A separate permissions policy determines the actions the role can perform on AWS resources.

## 4. Managed and Inline Policy Inventory

Commands:

```bash
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 iam list-attached-role-policies \
  --role-name CloudLabEC2Role --output json

aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 iam list-role-policies \
  --role-name CloudLabEC2Role --output json
```

Results:

| Policy type | Observed configuration |
|---|---|
| Managed | AmazonS3ReadOnlyAccess |
| Inline | None |

Managed policies are independent, reusable IAM policy resources.

Inline policies are embedded in a single identity.

## 5. Existing Managed Policy Analysis

Commands:

```bash
aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 iam get-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --query 'Policy.[PolicyName,DefaultVersionId]' \
  --output table

aws --endpoint-url=http://localhost:4566 \
  --region us-east-1 iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --version-id v3 \
  --query 'PolicyVersion.Document' --output json
```

Observed default version: v3

Observed permissions:

```json
{
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*",
        "s3:Describe*",
        "s3-object-lambda:Get*",
        "s3-object-lambda:List*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ],
  "Version": "2012-10-17"
}
```

### Security Finding

The existing policy grants broad S3 read-related permissions across applicable resources.

Although read-only permissions avoid ordinary write and delete operations, excessive read permissions can expose unrelated sensitive data.

Read-only is not equivalent to least privilege.

Other applicable policies, organizational restrictions, and service controls can still affect effective authorization.

## 6. Least-Privilege Policy Design

### Application Requirement

A Python application must read objects stored inside the illustrative S3 bucket cloudlab-app-data.

It does not require bucket listing, uploading, deletion, or access to unrelated buckets.

Created:

`week11/day1/s3-read-policy.json`

Contents:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadApplicationObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::cloudlab-app-data/*"
    }
  ]
}
```

### Action and Resource Scoping

| Requirement | IAM action | Resource |
|---|---|---|
| Download an object | s3:GetObject | arn:aws:s3:::cloudlab-app-data/* |
| List objects, if needed | s3:ListBucket | arn:aws:s3:::cloudlab-app-data |

The ListObjectsV2 API requires the s3:ListBucket IAM action.

The bucket-list permission was discussed but intentionally not included in the saved read-only object policy.

## 7. Local Validation

JSON syntax verification:

```bash
python3 -m json.tool week11/day1/s3-read-policy.json
```

Python assertions checked:

- Policy version equals 2012-10-17.
- Exactly one statement exists.
- Effect is Allow.
- Action equals s3:GetObject.
- Resource matches the intended object ARN.

Observed output:

```text
PASS: Valid policy structure for this exercise
PASS: Only s3:GetObject is granted
PASS: Access restricted to cloudlab-app-data objects
PASS: No wildcard action or unrestricted resource
```

### Limitations

The checks verify JSON syntax and the expected policy fields for this exercise.

They do not provide complete IAM policy-language validation, effective-permission simulation, or authorization testing against production AWS.

The illustrative bucket was not created or tested as part of this exercise.

## 8. Key Security Lessons

1. Least privilege requires restrictions on both actions and resources.
2. Role trust policies control who may assume a role.
3. Permissions policies define allowed actions and resource scope.
4. Temporary role credentials are generally preferable for AWS applications.
5. Managed policies may be broader than an application's actual requirements.
6. Resource-based policies can provide additional authorization paths.
7. Applicable explicit Deny takes precedence over Allow.
8. Bucket-level and object-level S3 permissions use different resource ARNs.
9. JSON validation does not prove successful authorization.
10. Existing infrastructure should be inspected before making security changes.

## 9. Troubleshooting and Observations

| Observation | Investigation or result |
|---|---|
| Initial IAM table output blank | JSON response confirmed an empty Users array |
| Existing EC2 role discovered | CloudLabEC2Role was present |
| Existing managed policy | AmazonS3ReadOnlyAccess, version v3 |
| Policy JSON | Syntax validation passed |
| Least-privilege assertions | All four checks passed |

No IAM resources were created, attached, detached, or deleted.

## 10. Outcome

Successfully completed an IAM security review and designed a narrowly scoped S3 object-read policy.

The existing CloudLabEC2Role and its AmazonS3ReadOnlyAccess attachment remain unchanged.

The new local policy is a design artifact and has not been deployed.

## Evidence

- [Least-privilege policy](./s3-read-policy.json)
- IAM inventory and trust-policy output verified during training
- Local Python policy assertions passed
- AWS IAM permissions and resource scope reviewed

## References

- [AWS IAM policies and permissions](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
- [AWS IAM policy evaluation logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html)
- [Amazon S3 policy actions](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html)
