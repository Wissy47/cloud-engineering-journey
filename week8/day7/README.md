# Week 8 Day 7 — Monitoring & Troubleshooting Mini Project

## Objective

Combine the Week 8 monitoring and troubleshooting concepts into one end-to-end incident investigation.

The project used:

- custom CloudWatch metrics
- CloudWatch alarms
- CloudWatch Logs
- request IDs
- CloudTrail audit evidence
- correlation analysis
- hypothesis formation
- mitigation
- recovery verification
- incident reporting

---

# Project Scenario

Service:

```text
checkout-api
```

Environment:

```text
production
```

Symptoms:

```text
high response time
checkout failures
```

The goal was to:

1. Detect the problem.
2. Investigate the metrics.
3. Inspect application logs.
4. Inspect audit/change evidence.
5. Identify the immediate failing dependency.
6. Form a hypothesis.
7. Recover the service.
8. Verify recovery.
9. Document the incident.

---

# Monitoring Design

Namespace:

```text
CloudLab/CheckoutProject
```

Dimension:

```text
Service=checkout-api
```

Metrics:

```text
ResponseTime
CheckoutFailures
RequestCount
```

Alarm:

```text
week8-checkout-failures
```

Configuration:

```text
Statistic:
Sum

Period:
60 seconds

EvaluationPeriods:
1

Threshold:
3

Comparison:
GreaterThanThreshold
```

Meaning:

```text
CheckoutFailures > 3
→ ALARM
```

---

# Healthy Baseline

Healthy metrics:

```text
ResponseTime = 180 ms
CheckoutFailures = 0
RequestCount = 120
```

Healthy request:

```text
request_id=checkout-001
status=200
duration_ms=180
```

This established the normal baseline.

---

# Audit Activity

A configuration object was uploaded:

```text
s3://week8-cloudtrail-source/config/checkout-config.json
```

CloudTrail recorded:

```text
eventSource = s3.amazonaws.com
eventName   = PutObject
readOnly    = false
```

The affected object was:

```text
config/checkout-config.json
```

This provided change/audit evidence before the incident.

However, this change was treated as:

```text
correlated activity
```

rather than a proven cause.

---

# Incident Metrics

During the incident:

```text
ResponseTime
180 ms → 1650 ms
```

and:

```text
CheckoutFailures
0 → 8
```

RequestCount changed only slightly:

```text
120 → 135
```

This indicated that the incident was not explained simply by a dramatic traffic increase.

---

# Alarm Detection

The CloudWatch alarm entered:

```text
ALARM
```

with:

```text
Threshold Crossed:
1 datapoint breaching the threshold
```

The configured threshold was:

```text
3
```

and the incident value was:

```text
8
```

Therefore:

```text
8 > 3
```

and the alarm condition was breached.

---

# ResponseTime Investigation

The metric statistics showed:

```text
Healthy:
180 ms
```

and later:

```text
Incident:
1650 ms
```

This provided clear quantitative evidence of severe latency degradation.

---

# Failure Logs

The failing request used:

```text
request_id=checkout-002
```

The log sequence showed:

```text
INFO checkout request received

WARN payment-service latency duration_ms=1650

ERROR payment-service timeout

ERROR checkout failed status=503
```

The failure path was:

```text
checkout request
       ↓
payment-service latency
       ↓
payment-service timeout
       ↓
checkout failure
       ↓
HTTP 503
```

---

# Immediate Failing Dependency

The logs identified:

```text
payment-service
```

as the immediate failing dependency.

This was supported by:

```text
latency = 1650 ms
timeout
HTTP 503
```

However:

```text
Immediate failing dependency
≠
Root cause
```

The evidence did not yet establish why `payment-service` became slow or unavailable.

---

# CloudTrail Evidence

CloudTrail recorded:

```text
PutObject
```

for:

```text
week8-cloudtrail-source
```

with key:

```text
config/checkout-config.json
```

This occurred shortly before the incident.

The correct conclusion was:

```text
configuration activity
+
incident shortly afterward
=
correlation
```

not:

```text
configuration activity
=
proven root cause
```

Additional testing would be required to establish causation.

---

# Incident Hypothesis

Based on the evidence:

```text
ResponseTime = 1650 ms
CheckoutFailures = 8
payment-service latency
payment-service timeout
HTTP 503
recent config object change
```

a reasonable hypothesis was:

```text
The checkout failure was related to the payment-service dependency.

A recent configuration change should be investigated as a possible contributing factor.
```

The configuration change was not declared the root cause because causation had not been proven.

---

# Recovery

Healthy recovery metrics were published:

```text
ResponseTime = 205 ms
CheckoutFailures = 0
```

A successful request was logged:

```text
request_id=checkout-003
status=200
duration_ms=205
```

---

# Recovery Verification

The CloudWatch alarm transitioned:

```text
ALARM
   ↓
OK
```

The final alarm reason indicated:

```text
missing datapoints treated as not breaching
```

because the alarm was configured using:

```text
treat-missing-data = notBreaching
```

Therefore the alarm state alone was not treated as the only recovery proof.

Recovery was confirmed using several signals:

```text
Alarm = OK
+
CheckoutFailures healthy
+
ResponseTime = 205 ms
+
HTTP 200
+
successful checkout log
```

Multiple independent signals provided stronger evidence of recovery.

---

# Final Incident Summary

```text
Incident:
Checkout API degradation and failures

Detection:
CloudWatch alarm

Impact:
Checkout requests failed

Healthy baseline:
ResponseTime = 180 ms
CheckoutFailures = 0

Incident evidence:
ResponseTime = 1650 ms
CheckoutFailures = 8
payment-service latency
payment-service timeout
HTTP 503

Immediate failing dependency:
payment-service

Correlated change:
checkout-config.json PutObject

Proven root cause:
Not established

Recovery evidence:
ResponseTime = 205 ms
CheckoutFailures = 0
HTTP 200
CloudWatch alarm = OK
```

---

# End-to-End Investigation Flow

```text
Alarm
  ↓
Metric investigation
  ↓
Identify incident timestamp
  ↓
Application logs
  ↓
Trace request ID
  ↓
Identify failing dependency
  ↓
Inspect audit/change evidence
  ↓
Form hypothesis
  ↓
Test / Mitigate
  ↓
Verify recovery
  ↓
Postmortem
```

---

# Week 8 Concepts Demonstrated

## Metrics

Metrics quantify system behavior.

Examples:

```text
ResponseTime
CheckoutFailures
RequestCount
```

---

## Statistics

Statistics summarize data points.

Examples:

```text
Average
Minimum
Maximum
Sum
SampleCount
```

---

## Alarm States

```text
OK
ALARM
INSUFFICIENT_DATA
```

---

## Logs

Logs provide detailed application context.

---

## Request IDs

Request IDs make it possible to trace the lifecycle of an individual request.

---

## CloudTrail

CloudTrail provides AWS API/account audit evidence.

---

## Hypothesis-Driven Troubleshooting

A hypothesis is a specific, testable explanation for available evidence.

Example:

```text
The recent security-group change may have blocked database connectivity.
```

It should be tested before being declared root cause.

---

## Correlation vs Causation

Correlation means events appear related.

Causation means one event actually produced another.

Correlation is evidence for investigation, not proof.

---

## Immediate Failing Dependency

The component currently exhibiting the failure.

It is not automatically the root cause.

---

## Mitigation

Reduce or stop the incident impact.

---

## Recovery

Return the service to healthy operation.

---

## Root Cause

The underlying reason the incident occurred.

---

## Postmortem

Document:

```text
what happened
impact
timeline
detection
root cause
mitigation
recovery
lessons
follow-up actions
```

---

# Key Lessons

- Metrics tell us what changed and by how much.
- Logs explain application behavior in detail.
- Alarms automate detection.
- CloudTrail provides AWS API/change evidence.
- Namespace and dimensions are part of metric identity.
- Average can hide important spikes.
- Count metrics often benefit from Sum.
- Alarm statistics strongly affect operational behavior.
- Request IDs make log investigations easier.
- Structured logs improve machine analysis.
- Management events and data events represent different activity types.
- Incident timelines help correlate evidence.
- Hypotheses must be testable.
- Change one thing at a time while troubleshooting.
- Correlation does not prove causation.
- Immediate failing dependency is not automatically root cause.
- Recovery should be verified with multiple signals.
- Postmortems turn incidents into operational improvements.

---
