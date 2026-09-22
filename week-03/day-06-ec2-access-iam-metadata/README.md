# Week 3 — Day 6: EC2 Access, IAM Roles & Instance Metadata

## Objectives

* Understand IAM roles for EC2
* Understand IAM policies
* Understand trust policies
* Understand instance profiles
* Understand the EC2 Instance Metadata Service
* Understand IMDSv2
* Understand temporary role credentials
* Understand the AWS credential provider chain
* Avoid hard-coded AWS credentials
* Compare real AWS behavior with Floci limitations

## IAM Roles for EC2

An EC2 instance can use an IAM role to access AWS services without storing long-lived credentials on the server.

Conceptually:

```text
EC2
↓
IAM Role
↓
Temporary credentials
↓
AWS services
```

This is safer than manually placing permanent access keys on an instance.

## IAM Role vs IAM Policy

An IAM role and IAM policy are different concepts.

```text
IAM Role
= identity

IAM Policy
= permissions
```

The role answers:

```text
Who is making the request?
```

The policy answers:

```text
What is that identity allowed to do?
```

## Trust Policy

The role created during the lab was:

```text
CloudLabEC2Role
```

Its trust policy allowed:

```text
ec2.amazonaws.com
```

to assume the role using:

```text
sts:AssumeRole
```

Conceptually:

```text
EC2
→ allowed to assume
→ CloudLabEC2Role
```

## Permission Policy

The AWS-managed policy:

```text
AmazonS3ReadOnlyAccess
```

was attached to the role.

This provided read-only access to Amazon S3.

The distinction is:

```text
Trust policy
→ WHO can assume the role

Permission policy
→ WHAT the role can do
```

## AWS-Managed Policies

`AmazonS3ReadOnlyAccess` is not a programming keyword.

It is the name of an AWS-managed IAM policy.

AWS-managed policies can be discovered using:

```bash
aws iam list-policies \
  --scope AWS \
  --query 'Policies[*].[PolicyName,Arn]' \
  --output table
```

A service-specific search can also be performed.

Example for S3:

```bash
aws iam list-policies \
  --scope AWS \
  --query "Policies[?contains(PolicyName, 'S3')].[PolicyName,Arn]" \
  --output table
```

## Instance Profile

An instance profile is used to deliver an IAM role to an EC2 instance.

Conceptually:

```text
IAM Policy
↓
IAM Role
↓
Instance Profile
↓
EC2
```

The instance profile created during the lab was:

```text
CloudLabEC2Profile
```

The role:

```text
CloudLabEC2Role
```

was added to the profile.

## IAM Resources Created

The lab successfully performed:

```text
Create IAM role               ✅
Attach AWS-managed policy     ✅
Create instance profile       ✅
Add role to instance profile  ✅
```

## Attaching the Instance Profile

On real AWS, a role can be associated with a running EC2 instance using:

```bash
aws ec2 associate-iam-instance-profile \
  --instance-id "$INSTANCE_ID" \
  --iam-instance-profile Name=CloudLabEC2Profile
```

Floci returned:

```text
UnsupportedOperation
```

Therefore the final association could not be completed in the local emulator.

## Instance Metadata Service

IMDS stands for:

**Instance Metadata Service**

The standard IPv4 address used by EC2 is:

```text
169.254.169.254
```

This is a link-local address used by every EC2 instance to access its own metadata.

It does not change per instance.

Examples of metadata include:

* Instance ID
* AMI ID
* Instance type
* Private IP
* Hostname
* Availability Zone
* IAM role information
* Temporary role credentials

## IMDSv2

IMDSv2 uses a session token.

Conceptually:

```text
Application
↓
Request metadata token
↓
Receive temporary token
↓
Use token in metadata request
↓
Receive metadata
```

A real EC2 instance can obtain a token with:

```bash
TOKEN=$(curl -s -X PUT \
  http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
```

Metadata can then be queried using:

```bash
curl \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/
```

Example:

```bash
curl \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

## Metadata Options Observed

The Floci instance reported:

```text
State: applied
HttpTokens: optional
HttpPutResponseHopLimit: 1
HttpEndpoint: enabled
HttpProtocolIpv6: disabled
InstanceMetadataTags: disabled
```

However, querying:

```text
http://169.254.169.254/latest/meta-data/
```

returned:

```text
HTTP/1.1 404 Not Found
```

Therefore Floci exposed the metadata configuration in its EC2 control plane but did not fully implement the real EC2 metadata service inside the container.

## Temporary Role Credentials

On real AWS, an EC2 instance with an attached IAM role can obtain temporary credentials through IMDS.

Temporary credentials contain values such as:

```text
AccessKeyId
SecretAccessKey
Token
Expiration
```

These credentials rotate automatically.

This is different from long-lived IAM user credentials.

## Credential Provider Chain

AWS SDKs and the AWS CLI can discover credentials automatically from multiple sources.

A simplified model is:

```text
Environment variables
↓
AWS credentials/config files
↓
Other configured credential providers
↓
EC2 IAM role credentials through IMDS
```

For an application running on EC2, IAM role credentials are generally preferable to hard-coded long-lived credentials.

## Why IAM Roles Are Preferred

Avoid:

```text
Application
→ permanent access key
→ permanent secret key
```

Prefer:

```text
Application
↓
EC2 role
↓
temporary credentials
↓
automatic rotation
```

This reduces the need to store credentials directly on the server.

## Example Real-AWS Workflow

```text
Application runs on EC2
↓
EC2 has instance profile
↓
Instance profile contains IAM role
↓
IAM role has required permissions
↓
AWS SDK queries credential provider chain
↓
Temporary credentials obtained automatically
↓
Application calls AWS API
```

For example, an application with appropriate S3 permissions could run:

```bash
aws s3 ls
```

without manually configuring permanent AWS credentials.

## Key Concepts Learned

* IAM roles provide identities to AWS workloads
* IAM policies define permissions
* Trust policies define who may assume a role
* Permission policies define what the role may do
* Instance profiles connect IAM roles to EC2
* `AmazonS3ReadOnlyAccess` is an AWS-managed policy
* AWS-managed policy names can be discovered with the IAM API
* IMDS uses `169.254.169.254`
* IMDSv2 uses temporary metadata tokens
* IAM role credentials are temporary
* AWS SDKs and the CLI can discover role credentials automatically
* Hard-coded long-lived credentials should be avoided
* Floci supports much of IAM resource creation but not EC2 instance-profile association in this environment
* Floci exposes metadata configuration but does not fully reproduce the real EC2 IMDS endpoint
