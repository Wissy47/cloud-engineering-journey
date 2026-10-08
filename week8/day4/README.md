# Week 8 Day 4 — CloudWatch Alarms & Notifications

## Objective

Learn how Amazon CloudWatch alarms automatically detect abnormal metric conditions and trigger operational responses.

The lab focused on:

- CloudWatch alarm states
- thresholds
- comparison operators
- periods
- evaluation periods
- M-out-of-N evaluation
- missing data
- metric identity
- alarm troubleshooting
- alarm actions
- Amazon SNS
- alarm fatigue
- designing useful monitoring alerts

---

# Monitoring Progression

Previous Week 8 labs covered:

```text
Day 1
→ Publish and understand metrics

Day 2
→ Analyze historical metrics

Day 3
→ Investigate application logs

Day 4
→ Automatically detect abnormal conditions
```

Without alarms:

```text
Engineer
   ↓
Check dashboard
   ↓
Notice problem
   ↓
Investigate
```

With alarms:

```text
Metric
   ↓
CloudWatch Alarm
   ↓
Condition breached?
   │
   ├── No → OK
   │
   └── Yes → ALARM
                 ↓
         Notification / Action
                 ↓
             Engineer
```

---

# CloudWatch Alarm States

CloudWatch metric alarms have three primary states.

## OK

The configured condition is not currently breached.

Example:

```text
Threshold = 80%

CPUUtilization = 35%

State = OK
```

---

## ALARM

The alarm's configured condition has been breached.

Example:

```text
Threshold = 80%

CPUUtilization = 92%

State = ALARM
```

---

## INSUFFICIENT_DATA

CloudWatch does not currently have enough suitable metric data to determine whether the condition is healthy or breached.

Example:

```text
Alarm created
     ↓
No recent metric data
     ↓
INSUFFICIENT_DATA
```

---

# Alarm Components

A useful alarm model is:

```text
Metric
+
Statistic
+
Period
+
Threshold
+
Comparison Operator
+
Evaluation Periods
```

Example:

```text
Metric:
ResponseTime

Statistic:
Average

Period:
60 seconds

Threshold:
500 ms

Comparison:
GreaterThanThreshold

EvaluationPeriods:
1
```

Meaning:

> If the evaluated average response time is greater than 500 ms, the alarm condition is breached.

---

# Metric Identity

The alarm must monitor the exact metric being published.

Metric identity includes important fields such as:

```text
Namespace
MetricName
Dimensions
```

Example:

```text
Namespace:
CloudLab/Payment

Metric:
PaymentFailures

Dimension:
Service=payment-api
```

If any of these do not match, the alarm may have no relevant datapoints to evaluate.

---

# Period

The period determines the size of each aggregation bucket.

Example:

```text
Period = 60
```

means:

```text
60 seconds
= one-minute bucket
```

---

# Evaluation Periods

Evaluation periods determine how many recent periods CloudWatch considers when deciding the alarm state.

Example:

```text
Period = 60
EvaluationPeriods = 3
```

means CloudWatch evaluates data across three one-minute periods.

Conceptually:

```text
Minute 1
Minute 2
Minute 3
    ↓
Alarm evaluation
```

---

# Avoiding One-Off Noise

Consider CPU utilization:

```text
40%
92%
41%
```

A one-period alarm could react to:

```text
92%
```

even though the resource immediately recovered.

A configuration requiring sustained abnormal behavior can reduce false or noisy alerts.

For example:

```text
85%
90%
93%
```

across multiple evaluated periods provides stronger evidence of a persistent issue.

---

# M-Out-of-N Alarms

Example:

```text
EvaluationPeriods = 5
DatapointsToAlarm = 3
```

means:

> At least 3 of the latest 5 evaluated datapoints must breach the threshold.

Example:

```text
Period 1 → breach
Period 2 → normal
Period 3 → breach
Period 4 → normal
Period 5 → breach
```

Three of five datapoints breached.

The breaching datapoints do not necessarily have to be consecutive.

---

# Thresholds

The threshold defines the boundary between expected and abnormal behavior.

Example:

```text
ResponseTime

0 ─────────────── 500 ─────────────►
        OK         │      ALARM
                   ↑
               Threshold
```

Given:

```text
Threshold = 500
Comparison = GreaterThanThreshold
```

a value above 500 is considered breaching.

---

# Comparison Operators

Common operators include:

```text
GreaterThanThreshold
GreaterThanOrEqualToThreshold
LessThanThreshold
LessThanOrEqualToThreshold
```

The correct operator depends on the metric.

Example:

```text
CPUUtilization > 80%
```

High values may indicate trouble.

But:

```text
FreeStorage < 10 GB
```

Low values may indicate trouble.

Therefore, alarm design requires understanding what the metric represents.

---

# Missing Data

The lab used:

```text
--treat-missing-data notBreaching
```

This means:

> Missing datapoints should not automatically count as threshold violations.

Missing data can occur because:

- an application stopped publishing
- a service is inactive
- there is a telemetry problem
- the metric has no recent activity

The appropriate missing-data behavior depends on the metric.

For a heartbeat metric, for example, missing data itself might indicate a serious problem.

---

# Statistic Selection

The selected statistic can completely change an alarm's behavior.

Consider:

```text
ResponseTime:

200
240
280
800
320
```

Statistics:

```text
Average = 368
Maximum = 800
```

Threshold:

```text
500
```

Using Average:

```text
368 < 500

State → OK
```

Using Maximum:

```text
800 > 500

State → ALARM
```

The underlying metric data is identical.

Only the statistic changed.

Therefore:

```text
Average
→ useful for overall or sustained behavior

Maximum
→ useful for detecting extreme spikes
```

---

# Checkout API Latency Alarm

An alarm was created for:

```text
Namespace:
CloudLab/Performance

Metric:
ResponseTime

Dimension:
Service=checkout-api
```

Configuration:

```text
Alarm:
checkout-api-high-latency

Statistic:
Average

Period:
60

EvaluationPeriods:
1

Threshold:
500

Comparison:
GreaterThanThreshold
```

Conceptually:

```text
ResponseTime
     ↓
Average
     ↓
60-second period
     ↓
> 500 ms ?
     │
     ├── No → OK
     └── Yes → ALARM
```

---

# Checkout API Error Alarm

Another alarm monitored:

```text
Metric:
ErrorCount

Statistic:
Sum

Threshold:
5
```

Meaning:

```text
ErrorCount Sum > 5
→ ALARM
```

This demonstrated that different metrics require different statistics.

---

# Payment API Hands-On Challenge

The independent challenge created:

```text
Alarm:
payment-api-failures
```

Metric definition:

```text
Namespace:
CloudLab/Payment

Metric:
PaymentFailures

Dimension:
Service=payment-api
```

Alarm configuration:

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
PaymentFailures > 3
→ ALARM
```

---

# Alarm Creation

The alarm was created using:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "payment-api-failures" \
  --alarm-description "Payment API failure count exceeds 3" \
  --namespace "CloudLab/Payment" \
  --metric-name "PaymentFailures" \
  --dimensions Name=Service,Value=payment-api \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

The alarm was successfully created.

---

# Initial Troubleshooting Issue

Initially, metric data was published as:

```text
Namespace:
CloudLab/Payment

MetricName:
ErrorCount
```

while the alarm was watching:

```text
MetricName:
PaymentFailures
```

The dimension was also initially published as:

```text
Service=payment-api-failures
```

rather than:

```text
Service=payment-api
```

Therefore the alarm and published metric identities did not match.

Conceptually:

```text
ALARM WATCHED

CloudLab/Payment
└── PaymentFailures
    └── Service=payment-api
```

but data was being published to:

```text
CloudLab/Payment
└── ErrorCount
    └── Service=payment-api-failures
```

These are different metrics.

The alarm therefore had no relevant datapoints to evaluate.

---

# Corrected Metric

The healthy metric was correctly published using:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/Payment" \
  --metric-data \
  'MetricName=PaymentFailures,Dimensions=[{Name=Service,Value=payment-api}],Value=1,Unit=Count' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Verification:

```bash
aws cloudwatch list-metrics \
  --namespace "CloudLab/Payment" \
  --metric-name "PaymentFailures" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

confirmed:

```text
MetricName:
PaymentFailures

Dimension:
Service=payment-api
```

---

# Triggering the Alarm

An unhealthy datapoint was then published:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/Payment" \
  --metric-data \
  'MetricName=PaymentFailures,Dimensions=[{Name=Service,Value=payment-api}],Value=6,Unit=Count' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

The condition was:

```text
Sum > 3
```

and:

```text
6 > 3
```

therefore the datapoint breached the alarm threshold.

---

# Alarm Evaluation Delay

Immediately after publishing the unhealthy datapoint, the alarm still showed:

```text
State:
OK
```

with a reason indicating missing datapoints were being treated as non-breaching.

On a later evaluation, the alarm changed to:

```text
State:
ALARM
```

with:

```text
Threshold Crossed:
1 datapoint breaching the threshold
```

This demonstrated an important operational lesson:

> Alarm evaluation and state transitions are not necessarily instantaneous.

Monitoring systems evaluate data according to their configured periods and evaluation behavior.

---

# Successful Alarm State

The final state became:

```text
Alarm:
payment-api-failures

Metric:
PaymentFailures

Threshold:
3

State:
ALARM
```

This proved that the CloudWatch alarm was evaluating the correct metric successfully.

---

# Amazon SNS

SNS stands for:

```text
Amazon Simple Notification Service
```

SNS can act as the message-distribution layer for CloudWatch alarm notifications.

Conceptually:

```text
CloudWatch Alarm
       ↓
    SNS Topic
       ↓
   Subscribers
```

Possible subscribers/actions can include:

```text
Email
SMS
Lambda
other systems
```

CloudWatch detects the condition.

SNS distributes the notification.

---

# Notification Architecture

Example:

```text
PaymentFailures
      ↓
CloudWatch Metric
      ↓
CloudWatch Alarm
      ↓
SNS Topic
      ↓
Engineering Team
```

The engineer can then:

```text
receive alert
     ↓
inspect metric
     ↓
identify timestamp
     ↓
inspect logs
     ↓
trace request
     ↓
identify root cause
```

---

# Alarm Fatigue

Alarm fatigue occurs when engineers receive too many low-value or unnecessary alerts.

Example:

```text
minor spike
→ alert

normal traffic increase
→ alert

temporary CPU activity
→ alert

expected maintenance
→ alert
```

Eventually engineers may start ignoring alerts.

That creates the risk that:

```text
critical incident
→ alarm
→ ignored
```

Good alarms should therefore be:

```text
Actionable
Meaningful
Specific
Low-noise
```

---

# Poor vs Better Alarm Design

Potentially noisy:

```text
CPU > 50%
for one minute
```

Potentially better for some workloads:

```text
CPU > 85%
for several minutes
```

or:

```text
3 of the last 5 periods > 85%
```

There is no universal threshold.

Alarm thresholds should be based on:

- workload behavior
- business impact
- historical baselines
- operational requirements

---

# Full Monitoring Flow

The complete monitoring flow now becomes:

```text
Resource/Application
        ↓
      Metric
        ↓
     Statistic
        ↓
      Period
        ↓
    Threshold
        ↓
 Alarm Evaluation
        ↓
  Alarm State
        ↓
Notification / Action
        ↓
     Engineer
        ↓
Metric Investigation
        ↓
     Log Search
        ↓
   Root Cause
```

---

# Key Lessons

- CloudWatch alarms automatically evaluate metric conditions.
- Alarm states include `OK`, `ALARM`, and `INSUFFICIENT_DATA`.
- An alarm is more than a threshold.
- Alarm design includes metric, statistic, period, threshold, comparison operator, and evaluation periods.
- Namespace, metric name, and dimensions must identify the correct metric.
- Period defines aggregation bucket size.
- Evaluation periods determine how many periods are considered.
- M-out-of-N alarms can reduce alert noise.
- Missing-data behavior must be chosen intentionally.
- Different statistics can produce different alarm outcomes.
- Average can hide extreme spikes.
- Maximum can expose short severe spikes.
- Alarm evaluation may not be instantaneous.
- SNS can distribute alarm notifications.
- Poorly designed alarms create alarm fatigue.
- Good alerts should be actionable and low-noise.
- Metric identity mismatches are an important alarm troubleshooting scenario.

---

