# Day 3 — AWS Fundamentals & IAM

## Objective

Understand the core structure of AWS and learn how identity, authentication, authorization, users, groups, roles, and policies work.

## Topics Covered

- AWS global infrastructure
- Regions and Availability Zones
- AWS services
- AWS accounts
- IAM
- Users
- Groups
- Roles
- Policies
- Authentication vs authorization
- Least privilege
- Root user security
- MFA
- AWS CLI identity

## AWS Global Infrastructure

AWS infrastructure is organized into:

```text
AWS
├── Regions
│   ├── Availability Zone A
│   ├── Availability Zone B
│   └── Availability Zone C
└── Edge locations
	us-east-1
	eu-west-1
	eu-central-1

IAM

IAM stands for:

Identity and Access Management

IAM controls:

Who can access AWS?
        +
What are they allowed to do?
Authentication vs Authorization
Authentication

Authentication answers:

Who are you?

Examples:

username/password
access keys
SSH keys
MFA
Authorization

Authorization answers:

What are you allowed to do?

AWS IAM policies are commonly used to define authorization.

IAM Users

An IAM user represents a person or application that needs access to AWS.

A user may have:

console access
access keys
permissions
group memberships
IAM Groups

Groups make it easier to assign the same permissions to multiple users.

Example:

Developers
├── Alice
├── Bob
└── Charlie

Instead of assigning the same policy individually to each user, permissions can be attached to the Developers group.

IAM Roles

A role is an AWS identity that can be assumed temporarily.

Roles are commonly used by:

EC2 instances
Lambda functions
AWS services
applications
users assuming temporary privileges

Example:

EC2 instance
     >
assumes IAM role
     >
gets temporary credentials
     >
accesses S3

This is generally preferable to storing permanent AWS access keys directly on a server.

IAM Policies

Policies are JSON documents describing permissions.

Conceptually:

Effect   → Allow or Deny
Action   → What operation?
Resource → Which AWS resource?

Example idea:

Allow
    >
s3:GetObject
    >
specific S3 bucket
Principle of Least Privilege

A user, role, or application should receive only the permissions required to perform its job.

Avoid:

AdministratorAccess everywhere

Prefer:

Only the required actions
        +
Only the required resources
Root User

The AWS account root user has unrestricted access to the AWS account.

Best practices include:

avoid using root for everyday work
enable MFA
protect root credentials
create IAM identities for normal administration
MFA

Multi-Factor Authentication adds another authentication factor in addition to a password.

Conceptually:

Something you know
        +
Something you have

This significantly improves account security.

AWS CLI Identity

The AWS CLI can check the currently authenticated identity with:

aws sts get-caller-identity

This can return information such as:

Account
UserId
Arn

During the local Floci labs, the emulator used test credentials rather than real AWS credentials.

Important IAM Mental Model
Identity
   >
Authentication
   >
IAM policies / roles
   >
Authorization
   >
AWS resource
Security Best Practices
Enable MFA
Avoid routine root-user usage
Follow least privilege
Prefer IAM roles over embedded access keys
Rotate or remove unused credentials
Never commit credentials to Git
Review permissions regularly
What I Learned

I learned how AWS organizes infrastructure across Regions and Availability Zones and how IAM controls access through users, groups, roles, and policies.

I also learned the distinction between authentication and authorization and why least privilege and temporary role-based credentials are important in cloud security.

Key Takeaway

IAM answers two fundamental cloud-security questions:

Who are you?
What are you allowed to do?

