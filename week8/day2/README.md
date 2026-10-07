# Week 8 Day 2 — CloudWatch Metrics Analysis

## Objective

Learn how to retrieve, aggregate, and interpret CloudWatch metric data.

The lab focused on:

- metric data points
- time ranges
- periods
- statistics
- SampleCount
- Sum
- Average
- Minimum
- Maximum
- trends
- spikes
- dimensions
- troubleshooting empty metric results
- percentiles
- incident-style metric analysis

---

## Environment

- macOS Apple Silicon
- AWS CLI
- floci
- Region: `us-east-1`
- Endpoint:

```text
http://localhost:4566
```

Environment variables:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

---

# Data Point vs Statistic

A data point is one individual measurement.

Example:

```text
ResponseTime = 250 ms
```

A statistic summarizes one or more measurements.

Example measurements:

```text
200
240
280
800
320
```

CloudWatch can calculate:

```text
Average
Minimum
Maximum
Sum
SampleCount
```

So:

```text
Data point
→ one measurement

Statistic
→ summary of measurements
```

---

# Time Range

The time range defines the total historical window being investigated.

Example:

```text
Last one hour
```

On macOS:

```bash
export END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export START_TIME=$(date -u -v-1H +"%Y-%m-%dT%H:%M:%SZ")
```

---

# Period

The period defines the aggregation bucket size inside the selected time range.

Example:

```text
Period = 60
```

means:

```text
60 seconds
= 1-minute buckets
```

The distinction is:

```text
Time range
→ entire investigation window

Period
→ bucket size inside that window
```

---

# Why Period Matters

A small period gives more detailed visibility.

Example:

```text
10:00 → 20%
10:01 → 30%
10:02 → 85%
10:03 → 31%
```

A larger aggregation period may instead show:

```text
Average = 41%
```

This can hide short-lived spikes.

Therefore, period selection is important when troubleshooting incidents.

---

# ResponseTime Metrics

Several application response-time measurements were published.

```text
180 ms
220 ms
310 ms
420 ms
```

These were queried using:

```bash
aws cloudwatch get-metric-statistics \
  --namespace "CloudLab/API" \
  --metric-name "ResponseTime" \
  --dimensions Name=Environment,Value=Development \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average Minimum Maximum \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

This demonstrated how CloudWatch aggregates multiple data points.

---

# Average Can Hide Problems

Consider:

```text
100
100
100
100
1000
```

The average is:

```text
280 ms
```

But one request took:

```text
1000 ms
```

If only the average were inspected, the spike might not be obvious.

Therefore:

```text
Average
→ typical behavior

Maximum
→ worst observed behavior

Minimum
→ best observed behavior
```

---

# SampleCount

`SampleCount` tells how many measurements contributed to the statistic.

Example:

```text
SampleCount = 5
```

means five measurements were aggregated.

This provides context for interpreting statistics.

For example:

```text
Average = 300
SampleCount = 2
```

is less representative than:

```text
Average = 300
SampleCount = 20,000
```

---

# Sum

`Sum` adds metric values in the aggregation period.

For a request count:

```text
120
150
200
```

the Sum would be:

```text
470
```

Sum is commonly useful for:

```text
RequestCount
ErrorCount
OrdersProcessed
JobsCompleted
```

---

# Choosing the Right Statistic

The correct statistic depends on the meaning of the metric.

Examples:

```text
RequestCount
→ Sum
```

```text
ErrorCount
→ Sum / Maximum
```

```text
CPUUtilization
→ Average / Maximum
```

```text
ResponseTime
→ Average / Maximum / percentile
```

Not every statistic is equally meaningful for every metric.

---

# Dimensions

Dimensions are part of the identity of a metric.

For example:

```text
APIRequests
Environment=Development
```

is different from:

```text
APIRequests
Environment=Production
```

If data was published using:

```text
Environment=Development
```

but queried using:

```text
Environment=Production
```

CloudWatch may correctly return no datapoints.

---

# Empty Datapoints Troubleshooting

If CloudWatch returns:

```json
{
  "Datapoints": []
}
```

check:

1. Namespace
2. Metric name
3. Dimensions
4. Start time
5. End time
6. Period
7. Whether data was actually published
8. Unit if relevant

An empty result does not automatically mean CloudWatch is broken.

---

# Hands-On Incident Challenge

A simulated performance incident was created using:

```text
Namespace:
CloudLab/Performance
```

Service dimension:

```text
Service=checkout-api
```

---

## ResponseTime Data

Published values:

```text
200
240
280
800
320
```

Unit:

```text
Milliseconds
```

The value:

```text
800 ms
```

represented a latency spike.

---

## ErrorCount Data

Published values:

```text
1
2
1
9
2
```

Unit:

```text
Count
```

The value:

```text
9
```

represented an error spike.

---

# ResponseTime Query

```bash
aws cloudwatch get-metric-statistics \
  --namespace "CloudLab/Performance" \
  --metric-name "ResponseTime" \
  --dimensions Name=Service,Value=checkout-api \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average Minimum Maximum SampleCount \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Result:

```text
SampleCount = 5
Average     = 368 ms
Minimum     = 200 ms
Maximum     = 800 ms
```

---

# ResponseTime Analysis

The average response time was:

```text
368 ms
```

but the maximum was:

```text
800 ms
```

This shows why average alone is insufficient.

The maximum exposed a significant latency spike.

---

# ErrorCount Query

```bash
aws cloudwatch get-metric-statistics \
  --namespace "CloudLab/Performance" \
  --metric-name "ErrorCount" \
  --dimensions Name=Service,Value=checkout-api \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum Maximum SampleCount \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Result:

```text
SampleCount = 5
Sum         = 15
Maximum     = 9
```

---

# Error Analysis

The five measurements were:

```text
1
2
1
9
2
```

CloudWatch showed:

```text
Total errors = 15
Largest measurement = 9
```

The value of 9 was clearly abnormal compared with the other measurements.

---

# Correlation and Causation

The lab contained:

```text
ResponseTime spike = 800 ms
ErrorCount spike   = 9
```

However, the returned timestamps were different.

Therefore, it cannot be concluded from this data alone that the latency spike caused the error spike.

A real investigation would compare:

```text
ResponseTime
ErrorCount
CPU
Memory
deployments
application logs
database activity
```

at matching timestamps.

This is an important observability principle:

```text
Correlation
does not automatically prove
causation
```

---

# Percentiles

Percentiles are especially useful for latency.

Example:

```text
p95 = 400 ms
```

means approximately:

```text
95% of observed requests
were at or below
400 ms
```

Percentiles help reveal slow-tail performance that averages can hide.

Common percentiles include:

```text
p50
p90
p95
p99
```

---

# Monitoring Workflow

The Day 2 workflow is:

```text
Metric
   ↓
Data points
   ↓
Time range
   ↓
Period
   ↓
Statistics
   ↓
Trend analysis
   ↓
Investigation
```

The engineer first selects the relevant metric and historical window.

CloudWatch then groups data using the chosen period and calculates statistics.

The results are analyzed for:

- spikes
- unusual values
- trends
- correlations
- potential incidents

---

# Key Lessons

- A data point is one individual measurement.
- A statistic summarizes metric data.
- Time range defines the entire investigation window.
- Period defines aggregation bucket size.
- Large periods can hide short spikes.
- Average shows typical behavior.
- Maximum shows worst observed behavior.
- Minimum shows best observed behavior.
- Sum shows total activity.
- SampleCount shows how many measurements contributed.
- The correct statistic depends on the metric.
- Dimensions must match when querying metrics.
- Empty datapoints may indicate a query mismatch rather than a CloudWatch problem.
- Percentiles are useful for latency analysis.
- Metrics must be aligned by timestamp before inferring relationships between events.

---
