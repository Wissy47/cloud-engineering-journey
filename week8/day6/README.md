# Week 8 Day 6 — Troubleshooting & Incident Response

## Objective

Learn how to investigate cloud incidents systematically by combining metrics, alarms, application logs, infrastructure knowledge, audit evidence, hypotheses, mitigation, recovery verification, and post-incident analysis.

The lab focused on:

- incident detection
- impact and blast radius
- incident timelines
- metrics
- alarms
- logs
- CloudTrail
- infrastructure dependencies
- hypothesis-driven troubleshooting
- correlation vs causation
- mitigation
- root cause
- recovery verification
- postmortems

---

# Structured Incident Response

A useful incident-response workflow is:

```text
Detect
  ↓
Scope
  ↓
Gather Evidence
  ↓
Form Hypothesis
  ↓
Test Hypothesis
  ↓
Find Root Cause
  ↓
Mitigate
  ↓
Verify Recovery
  ↓
Document
```

The main principle is:

```text
Evidence first
Assumptions second
```

Random troubleshooting can hide evidence and make incidents harder to understand.

---

# Detection

Detection means discovering that something abnormal is happening.

Examples include:

```text
CloudWatch alarm enters ALARM
ErrorCount increases
ResponseTime increases
application logs contain errors
users report failures
```

Detection tells us:

```text
Something is wrong.
```

It does not automatically tell us:

```text
Why it is wrong.
```

---

# Impact

Impact describes what was affected.

Examples:

```text
payment requests failing
customers unable to log in
database unavailable
API response time degraded
```

Impact should focus on actual effects rather than simply the existence of an error.

---

# Blast Radius

Blast radius describes how widespread the incident is.

Questions include:

```text
Which service?
Which environment?
Which users?
Which instances?
Which region?
Which dependencies?
```

Example:

```text
payment-api → unhealthy

checkout-api → healthy
```

This suggests that the incident may be localized to the payment system rather than affecting the entire platform.

---

# Incident Timeline

A timeline establishes the order of events.

Example:

```text
14:00 deployment completed
14:03 DB failures begin
14:04 ErrorCount increases
14:05 alarm triggers
14:07 engineer investigates
14:10 issue identified
14:12 mitigation applied
14:13 requests recover
14:14 alarm returns OK
```

Timelines help correlate symptoms with changes and guide investigation.

---

# Metrics During Incident Response

Metrics provide quantitative evidence about system behavior.

Examples:

```text
ResponseTime = 1450 ms
PaymentFailures = 7
CPUUtilization = 95%
```

Metrics help answer:

```text
What changed?
When did it change?
How severe was the change?
```

They can narrow the investigation but do not always reveal root cause.

---

# Alarms

CloudWatch alarms automatically identify when configured metric conditions become operationally significant.

Example:

```text
PaymentFailures
      ↓
Sum
      ↓
60-second period
      ↓
Threshold > 3
      ↓
ALARM
```

An alarm tells us that a monitored condition has breached its configured threshold.

It does not tell us why that condition occurred.

---

# Logs

Application logs provide detailed context.

Example:

```text
INFO payment request received

WARN payment gateway latency duration_ms=1450

ERROR payment gateway timeout

ERROR payment failed status=503
```

Logs can reveal:

```text
specific request
failing operation
dependency involved
error message
response status
latency
```

---

# Request IDs

Request IDs make it possible to trace one request across multiple log events.

Example:

```text
request_id=incident-001
```

The incident request could then be reconstructed from beginning to failure.

---

# CloudTrail

CloudTrail contributes AWS account/API-change evidence.

It can help answer:

```text
Did infrastructure change?

Who changed it?

When?

Which API operation?

Which resource?

What parameters were used?
```

Potentially relevant events include:

```text
ModifyDBInstance
AuthorizeSecurityGroupIngress
RevokeSecurityGroupIngress
AttachRolePolicy
```

CloudTrail is particularly useful when an incident appears shortly after an infrastructure configuration change.

---

# Infrastructure Dependencies

Application failures may originate below the application layer.

A useful troubleshooting path is:

```text
Application
    ↓
DNS
    ↓
TCP Connectivity
    ↓
Routing
    ↓
Security Groups / NACLs
    ↓
Target Service
    ↓
Authentication
```

These layers should be tested systematically rather than skipped.

---

# Example Database Investigation

Suppose logs show:

```text
ERROR database connection timeout
```

A useful investigation might check:

```text
1. Does DNS resolve?

2. Is the host reachable?

3. Is the required TCP port reachable?

4. Is routing correct?

5. Do SG/NACL rules permit traffic?

6. Is the database running?

7. Are authentication credentials valid?
```

Different symptoms point toward different layers.

For example:

```text
Connection timeout
→ likely connectivity/network path investigation
```

while:

```text
Authentication failed
→ connectivity may already be working
```

---

# Hypothesis-Driven Troubleshooting

A hypothesis is a specific, testable explanation for observed evidence.

Example evidence:

```text
DB timeout errors began
shortly after an SG rule changed
```

Hypothesis:

```text
The SG change blocked application access
to the database.
```

Test:

```text
Check whether the required DB port
is permitted between the application
and database security groups.
```

A hypothesis should be tested rather than assumed to be true.

---

# Change One Thing at a Time

Poor troubleshooting:

```text
restart app
modify SG
modify route
change credentials
restart database
```

all at once.

If the application recovers, it is difficult to determine which change fixed it.

Better troubleshooting:

```text
Hypothesis
    ↓
Single test
    ↓
Observe result
    ↓
Accept/reject hypothesis
```

This preserves useful evidence.

---

# Correlation vs Causation

Correlation means two events appear related.

Example:

```text
13:58 SG changed
14:00 DB failures begin
```

That timing is suspicious.

However, it does not yet prove:

```text
SG change caused DB failure
```

Causation requires evidence demonstrating that the first event produced the second.

The correct approach is:

```text
Observe correlation
      ↓
Form hypothesis
      ↓
Test hypothesis
      ↓
Collect evidence
      ↓
Determine causation
```

---

# Mitigation vs Root Cause

Mitigation means reducing or stopping the incident's impact.

Examples:

```text
restore previous configuration
fail over traffic
restart failed dependency
rollback deployment
```

Root cause is the underlying reason the incident occurred.

These are not the same.

Example:

```text
Mitigation:
Restore SG rule.

Root cause:
Deployment automation accidentally removed required rule.
```

Service can sometimes be restored before root cause is fully understood.

---

# Immediate Failing Dependency vs Root Cause

An important lesson from the Day 6 lab was:

```text
Immediate failing dependency
≠
Root cause
```

The logs identified:

```text
Payment gateway
```

as the immediate failing dependency.

However, the lab did not establish why the payment gateway became slow or unavailable.

Possible causes might include:

```text
network issue
gateway outage
DNS issue
bad deployment
resource exhaustion
configuration change
```

but none were proven.

Therefore:

```text
Immediate failing dependency:
Payment gateway

Root cause:
Not yet proven
```

---

# Recovery Verification

Mitigation must be followed by verification.

Never assume:

```text
"I changed something,
so the system must be healthy."
```

Useful recovery evidence includes:

```text
Alarm returns to OK
ErrorCount declines
ResponseTime returns to normal
successful application requests
dependency becomes reachable
```

Multiple independent signals provide stronger evidence than a single successful request.

---

# Incident Simulation

The Day 6 practical lab simulated a Payment API incident.

Architecture:

```text
Payment API
   │
   ├── CloudWatch Metrics
   │         ↓
   │       Alarm
   │
   └── CloudWatch Logs
```

Incident scenario:

```text
Payment gateway latency
        ↓
Gateway timeout
        ↓
Payment request fails
        ↓
PaymentFailures increases
        ↓
Alarm enters ALARM
```

---

# Healthy Baseline

Initial healthy behavior used values such as:

```text
ResponseTime = 190 ms
PaymentFailures = 1
```

This provided a baseline for comparison with the incident.

---

# Incident Alarm

The incident alarm monitored:

```text
Namespace:
CloudLab/Incident

Metric:
PaymentFailures

Dimension:
Service=payment-api

Statistic:
Sum

Period:
60 seconds

Threshold:
3

Comparison:
GreaterThanThreshold
```

The condition was:

```text
PaymentFailures > 3
→ ALARM
```

---

# Failure Metrics

The incident published:

```text
ResponseTime = 1450 ms

PaymentFailures = 7
```

The failure metric breached the configured threshold.

The CloudWatch alarm entered:

```text
ALARM
```

with:

```text
Threshold Crossed:
1 datapoint breaching the threshold
```

---

# Failure Logs

The request was identified using:

```text
request_id=incident-001
```

The logs showed:

```text
INFO payment request received

WARN payment gateway latency duration_ms=1450

ERROR payment gateway timeout

ERROR payment failed status=503
```

The failure path was:

```text
Request received
      ↓
Gateway latency = 1450 ms
      ↓
Gateway timeout
      ↓
Payment failed
      ↓
HTTP 503
```

---

# Why 1450 ms Was Important

`duration_ms=1450` quantified the performance degradation.

Healthy response:

```text
210 ms
```

Incident response:

```text
1450 ms
```

This showed that latency increased significantly before the request failed.

The value provided measurable evidence rather than relying only on:

```text
"The gateway was slow."
```

---

# HTTP 503

The failure returned:

```text
status=503
```

HTTP 503 means:

```text
Service Unavailable
```

It indicates the service was temporarily unable to fulfill the request.

This supported the evidence that the payment operation was failing at the service/dependency level.

---

# Incident Hypothesis

Evidence:

```text
ResponseTime = 1450 ms

PaymentFailures = 7

payment gateway latency warning

payment gateway timeout

HTTP 503
```

Reasonable hypothesis:

```text
The payment gateway dependency became
slow or unavailable, causing payment
requests to timeout and fail.
```

This identified the immediate failing dependency.

It did not establish the gateway's underlying root cause.

---

# Recovery

Recovery metrics were then published:

```text
ResponseTime = 210 ms

PaymentFailures = 0
```

A successful request was also logged:

```text
request_id=incident-002

payment completed

status=200

duration_ms=210
```

---

# Alarm Recovery

The CloudWatch alarm transitioned:

```text
ALARM
   ↓
OK
```

with the reason:

```text
Threshold Not Crossed:
0 datapoint(s) breaching the threshold
```

This proved that the configured alarm condition was no longer being breached.

---

# Recovery Evidence

Several independent signals demonstrated recovery:

```text
PaymentFailures healthy
        +
ResponseTime = 210 ms
        +
HTTP 200 successful request
        +
CloudWatch Alarm = OK
```

This is stronger evidence than relying on one successful request alone.

---

# Incident Timeline

The simulated incident can be reconstructed as:

```text
1. Payment request received

2. Payment gateway latency increased to 1450 ms

3. Payment gateway timed out

4. Payment request failed with HTTP 503

5. PaymentFailures breached threshold

6. CloudWatch alarm entered ALARM

7. Dependency/service recovered

8. ResponseTime returned to 210 ms

9. PaymentFailures returned to healthy level

10. New payment completed with HTTP 200

11. CloudWatch alarm returned to OK
```

---

# Incident Summary

```text
Incident:
Payment API failures

Detection:
CloudWatch Alarm

Impact:
Payment request failure

Failure evidence:
ResponseTime = 1450 ms
PaymentFailures = 7
Gateway timeout
HTTP 503

Immediate failing dependency:
Payment gateway

Mitigation / Recovery:
Dependency returned to healthy behavior

Recovery evidence:
ResponseTime = 210 ms
PaymentFailures = 0
HTTP 200
Alarm = OK

Root cause:
Not proven from available evidence
```

---

# Incident Terminology

## Detection

Discovering the problem.

## Impact

What users/services/business functions were affected.

## Blast Radius

How widespread the impact was.

## Mitigation

Reducing or stopping the immediate impact.

## Recovery

Returning systems to normal operation.

## Root Cause

Underlying reason the incident occurred.

## Postmortem

Post-incident documentation and analysis used to understand the incident and reduce the chance of recurrence.

---

# Postmortem

Recovery should not end the engineering process.

After an incident, investigate:

```text
What happened?

When did it begin?

What was affected?

How was it detected?

Why did it happen?

What fixed it?

What made it worse?

How can it be prevented?

How can it be detected faster next time?
```

A good postmortem can include:

```text
summary
impact
timeline
root cause
contributing factors
detection
mitigation
recovery
lessons learned
follow-up actions
```

---

# Key Lessons

- Incident response should follow a structured process.
- Detection does not equal diagnosis.
- Determine impact and blast radius early.
- Build a timeline.
- Metrics provide quantitative evidence.
- Alarms automate detection.
- Logs provide detailed application context.
- CloudTrail provides AWS API/change evidence.
- Infrastructure should be troubleshot layer by layer.
- Use hypotheses rather than random changes.
- Change one thing at a time.
- Correlation does not prove causation.
- Mitigation and root cause are different.
- Immediate failing dependency is not necessarily root cause.
- Recovery must be verified.
- Multiple signals provide stronger recovery evidence.
- Postmortems turn incidents into engineering improvements.

---
