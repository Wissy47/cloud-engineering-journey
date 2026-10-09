# Week 8 Day 5 — CloudTrail & Audit Logging

## Objective

Learn how AWS CloudTrail records AWS account and API activity for auditing, security investigation, governance, and troubleshooting.

The lab focused on:

- CloudWatch vs CloudTrail
- CloudTrail events
- management events
- data events
- read vs write activity
- Event History
- trails
- S3 log delivery
- event fields
- user identity
- source IP
- request parameters
- resource information
- floci CloudTrail limitations and supported S3 data-event flow

---

# CloudWatch vs CloudTrail

CloudWatch and CloudTrail solve different monitoring problems.

## CloudWatch

CloudWatch helps answer:

```text
What is happening in my system?
```

Examples:

```text
CPU is high
Response time increased
Error count increased
Application logs contain failures
```

---

## CloudTrail

CloudTrail helps answer:

```text
Who performed an AWS action?
What action was performed?
When?
From where?
Which resource was affected?
```

Examples:

```text
Who modified a security group?
Who created an IAM role?
Who uploaded an S3 object?
Who changed an RDS configuration?
```

A useful mental model is:

```text
CloudWatch
→ system/application behavior

CloudTrail
→ AWS API/account activity
```

---

# CloudTrail Event

A CloudTrail event represents one recorded AWS activity.

Examples:

```text
PutObject
GetObject
CreateSecurityGroup
ModifyDBInstance
CreateRole
```

A CloudTrail event can include:

```text
eventTime
eventSource
eventName
userIdentity
sourceIPAddress
requestParameters
resources
readOnly
eventCategory
```

---

# Management Events

Management events are control-plane operations.

They relate to creating, configuring, modifying, or inspecting AWS infrastructure.

Examples:

```text
CreateVpc
CreateSubnet
CreateSecurityGroup
ModifyDBInstance
DescribeSecurityGroups
AttachRolePolicy
```

Management events can be divided into:

```text
Read operations
Write operations
```

---

# Read Management Events

Read events inspect infrastructure without changing it.

Examples:

```text
DescribeVpcs
DescribeSecurityGroups
DescribeDBInstances
```

---

# Write Management Events

Write events change infrastructure.

Examples:

```text
CreateSecurityGroup
DeleteSecurityGroup
ModifyDBInstance
AuthorizeSecurityGroupIngress
```

During an incident investigation, write events are often especially important because they may explain what changed.

---

# Data Events

Data events are data-plane operations performed on or inside AWS resources.

Examples include S3 object-level operations such as:

```text
PutObject
GetObject
HeadObject
DeleteObject
ListObjects
```

A useful distinction is:

```text
Management event
→ configure/manage the AWS resource

Data event
→ interact with the data inside/on the resource
```

---

# Event History

On real AWS, CloudTrail Event History provides recent management-event history.

A useful distinction is:

```text
Event History
→ recent built-in history

Trail
→ configuration for ongoing event delivery
```

---

# CloudTrail Trail

A trail defines how CloudTrail events are delivered.

Typical architecture:

```text
AWS API Activity
       ↓
CloudTrail
       ↓
Trail
       ↓
S3 Bucket
```

S3 is commonly used because it provides durable object storage suitable for long-term audit records.

---

# Initial EC2 Audit Experiment

An initial experiment used EC2 security-group operations such as:

```text
CreateSecurityGroup
AuthorizeSecurityGroupIngress
DescribeSecurityGroups
```

The commands succeeded, but:

```bash
aws cloudtrail lookup-events \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

returned:

```json
{
  "Events": []
}
```

Filtering for:

```text
EventName=CreateSecurityGroup
```

also returned no events.

This was identified as a floci CloudTrail integration limitation rather than an AWS CLI syntax problem.

The documented CloudTrail event-generation flow used for this lab is based on supported S3 data events.

---

# Updated floci CloudTrail Lab

Two buckets were used:

```text
week8-cloudtrail-source
week8-cloudtrail-logs
```

The first bucket generated object activity.

The second bucket stored CloudTrail log files.

Architecture:

```text
week8-cloudtrail-source
        ↓
S3 object operations
        ↓
CloudTrail
        ↓
Trail
        ↓
week8-cloudtrail-logs
```

---

# Create Trail

The CloudTrail trail was created using:

```bash
aws cloudtrail create-trail \
  --name week8-cloudtrail \
  --s3-bucket-name week8-cloudtrail-logs \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

# S3 Data Event Selector

The trail was configured for S3 object data events using:

```text
AWS::S3::Object
```

for:

```text
arn:aws:s3:::week8-cloudtrail-source/
```

This allowed S3 object operations to be recorded.

---

# Generate Audit Activity

A test file was created:

```text
cloudtrail-test.txt
```

and uploaded to:

```text
s3://week8-cloudtrail-source/
```

The lab then performed activities including:

```text
PutObject
HeadObject
GetObject
ListObjects
```

---

# CloudTrail Log Delivery

CloudTrail successfully created a compressed audit file in the log bucket:

```text
AWSLogs/000000000000/CloudTrail/us-east-1/2026/10/09/...
```

The file used the format:

```text
.json.gz
```

This confirmed that the trail captured the S3 activity and delivered audit logs to S3.

---

# Inspecting the Audit Log

The log object was downloaded:

```bash
aws s3 cp \
  s3://week8-cloudtrail-logs/AWSLogs/...json.gz \
  /tmp/cloudtrail.json.gz \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

It was decompressed:

```bash
gunzip -c /tmp/cloudtrail.json.gz > /tmp/cloudtrail.json
```

and inspected:

```bash
cat /tmp/cloudtrail.json
```

or:

```bash
jq . /tmp/cloudtrail.json
```

---

# Captured Events

The CloudTrail log contained:

```text
PutObject
HeadObject
GetObject
ListObjects
```

All events showed:

```text
eventSource = s3.amazonaws.com
```

and:

```text
eventCategory = Data
```

with:

```text
managementEvent = false
```

This confirmed they were S3 data events.

---

# eventName

`eventName` identifies the AWS API operation.

Examples from the lab:

```text
PutObject
HeadObject
GetObject
ListObjects
```

This answers:

```text
What happened?
```

---

# eventSource

`eventSource` identifies which AWS service handled the API request.

In the lab:

```text
s3.amazonaws.com
```

This tells us the event came from Amazon S3.

---

# eventTime

`eventTime` records when the operation occurred.

Example:

```text
2026-10-09T14:50:01Z
```

This is important when correlating CloudTrail activity with:

```text
metrics
alarms
application logs
incidents
```

---

# userIdentity

The lab recorded identity information including:

```text
type
principalId
arn
accountId
accessKeyId
userName
```

In the floci environment:

```text
userName = root
accessKeyId = test
accountId = 000000000000
```

These are emulator identities.

On real AWS, this field is extremely useful for determining which IAM user, role, assumed role, service, or other identity performed an action.

---

# sourceIPAddress

The captured events showed:

```text
sourceIPAddress = 192.168.65.1
```

This indicates where the request originated from in the local Docker/macOS environment.

In real AWS investigations, this field can help identify the source of suspicious API activity.

---

# userAgent

The event also recorded information about the client used.

The lab showed AWS CLI information such as:

```text
aws-cli/2.36.40
```

and commands such as:

```text
s3.cp
s3.ls
```

This helps determine how the operation was performed.

---

# requestParameters

`requestParameters` showed exactly which resource was involved.

For `PutObject`:

```text
bucketName = week8-cloudtrail-source
key        = cloudtrail-test.txt
```

This answers:

```text
Which bucket?
Which object?
```

---

# Resources

The CloudTrail events included resource information.

For object operations:

```text
AWS::S3::Bucket
arn:aws:s3:::week8-cloudtrail-source
```

and:

```text
AWS::S3::Object
arn:aws:s3:::week8-cloudtrail-source/cloudtrail-test.txt
```

This makes it possible to identify the exact affected AWS resource.

---

# readOnly

The `readOnly` field helps classify the operation.

## PutObject

```text
readOnly = false
```

This is correct because `PutObject` writes or changes data.

---

## GetObject

```text
readOnly = true
```

because the operation retrieves data without changing it.

---

## HeadObject

```text
readOnly = true
```

because it inspects object metadata.

---

## ListObjects

```text
readOnly = true
```

because it lists existing objects without changing them.

---

# Audit Sequence

The complete lab flow was:

```text
AWS CLI
   ↓
PutObject
   ↓
cloudtrail-test.txt uploaded
   ↓
HeadObject
   ↓
object metadata checked
   ↓
GetObject
   ↓
object retrieved
   ↓
ListObjects
   ↓
bucket contents listed
   ↓
CloudTrail records events
   ↓
Trail delivers log file to S3
```

---

# CloudTrail Investigation Questions

A useful CloudTrail investigation should try to answer:

```text
WHO?
WHAT?
WHEN?
WHERE?
WHICH RESOURCE?
WHAT PARAMETERS?
```

Relevant fields include:

```text
WHO
→ userIdentity

WHAT
→ eventName

WHEN
→ eventTime

WHERE
→ sourceIPAddress

WHICH SERVICE
→ eventSource

WHAT PARAMETERS
→ requestParameters

WHICH RESOURCE
→ resources
```

---

# CloudWatch + Logs + CloudTrail

These observability tools complement each other.

```text
CloudWatch Metrics
→ Something abnormal happened

CloudWatch Alarm
→ Automatically detected the abnormality

CloudWatch Logs
→ What happened inside the application

CloudTrail
→ What AWS API/account activity occurred
```

A complete investigation can look like:

```text
CloudWatch alarm
       ↓
Metric anomaly
       ↓
Find timestamp
       ↓
Application logs
       ↓
Find application error
       ↓
CloudTrail
       ↓
Find AWS configuration/API activity
       ↓
Root cause investigation
```

---

# Example Incident

Imagine:

```text
PaymentFailures increase
```

CloudWatch shows:

```text
PaymentFailures = 20
```

Alarm changes to:

```text
ALARM
```

Application logs show:

```text
ERROR database connection refused
```

CloudTrail might then reveal:

```text
RevokeSecurityGroupIngress
```

shortly before the incident.

Possible chain:

```text
Security configuration changed
        ↓
Database connectivity blocked
        ↓
Application database failures
        ↓
Payment failures
        ↓
CloudWatch alarm
```

This shows how monitoring and audit logging can work together.

---

# floci vs Real AWS

The lab demonstrated an important emulator lesson.

Real AWS CloudTrail records a broad range of management events.

Our floci environment exposes CloudTrail APIs but the practical event-generation integration documented and verified in this lab focused on S3 data events.

Therefore:

```text
EC2 API operation
→ resource changed
→ no CloudTrail event returned in this floci test
```

while:

```text
S3 object operation
→ CloudTrail data event
→ log delivered to S3
```

worked successfully.

This is a local-emulator limitation, not an AWS CloudTrail limitation.

---

# Key Lessons

- CloudWatch monitors behavior.
- CloudTrail audits AWS API/account activity.
- CloudTrail events contain detailed activity context.
- Management events relate to infrastructure control-plane operations.
- Data events relate to operations on/in resources.
- Event History and Trails are different concepts.
- S3 is commonly used for long-term CloudTrail storage.
- `eventName` identifies the API operation.
- `eventSource` identifies the AWS service.
- `eventTime` identifies when the event happened.
- `userIdentity` identifies the acting identity.
- `sourceIPAddress` helps identify request origin.
- `requestParameters` shows request details.
- `resources` identifies affected resources.
- `readOnly=false` indicates a write/change operation.
- `readOnly=true` indicates a read/inspection operation.
- CloudTrail can be correlated with metrics and logs during incident investigation.
- floci CloudTrail behavior differs from real AWS and must be understood when using the emulator.

---

