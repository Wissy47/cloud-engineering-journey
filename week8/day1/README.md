# Week 8 Day 1 — CloudWatch Fundamentals

## Objective

Learn the fundamentals of Amazon CloudWatch and understand how metrics, logs, alarms, dashboards, namespaces, dimensions, and statistics work together to monitor cloud infrastructure and applications.

The lab focused on:

- CloudWatch monitoring concepts
- Metrics
- Logs
- Namespaces
- Dimensions
- Time series
- Metric statistics
- Custom application metrics
- Infrastructure vs application monitoring
- AWS CLI metric publishing
- floci CloudWatch emulation

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

# What Is Monitoring?

Monitoring allows engineers to understand whether infrastructure and applications are behaving correctly.

Without monitoring, problems may only become visible after users report them.

With monitoring, engineers can observe measurements such as:

```text
CPU utilization
Memory usage
Request count
Error count
Response time
Database connections
```

Monitoring provides evidence for troubleshooting rather than relying on guesses.

---

# CloudWatch

Amazon CloudWatch is AWS's monitoring and observability service.

A basic monitoring flow is:

```text
Resource
   │
   ▼
Measurements
   │
   ▼
CloudWatch
   │
   ├── Metrics
   ├── Logs
   ├── Alarms
   └── Dashboards
```

---

# Metrics

A metric is a numerical measurement recorded over time.

Examples:

```text
CPUUtilization = 32%
RequestCount = 120
ErrorCount = 7
ResponseTime = 250 ms
```

Metrics answer questions such as:

```text
How much?
How many?
How fast?
How high?
```

---

# Logs

Logs contain detailed information about events that happened.

Example:

```text
10:01 User logged in
10:02 GET /projects
10:03 Database connection failed
10:04 HTTP 500 returned
```

A useful distinction is:

```text
Metric
→ Something is wrong.

Log
→ This is what happened.
```

For example:

```text
Metric:
ErrorCount = 25

Log:
ERROR: PostgreSQL connection timeout
```

---

# Metrics vs Logs

Metrics are numerical measurements.

Logs are detailed event records.

They are commonly used together during troubleshooting:

```text
Alarm triggered
      ↓
Inspect metric
      ↓
Inspect logs
      ↓
Find root cause
```

---

# Namespace

A namespace is a container for related CloudWatch metrics.

Examples:

```text
AWS/EC2
AWS/RDS
CloudLab/Application
CloudLab/API
CloudLab/Servers
```

For an application:

```text
CloudLab/API
│
├── APIRequests
├── APIErrors
└── ResponseTime
```

Namespaces help organize and isolate monitoring data.

---

# Metric Name

The metric name defines what is being measured.

Examples:

```text
CPUUtilization
RequestCount
ErrorCount
ResponseTime
APIRequests
APIErrors
```

---

# Dimensions

A dimension is a name/value pair that adds context to a metric.

Example:

```text
Metric:
APIErrors

Dimension:
Environment=Development
```

Other possible dimensions include:

```text
Server=web-01

Environment=Production

InstanceId=i-123456

Application=checkout-api
```

Dimensions form part of a metric's identity.

Therefore:

```text
APIErrors
Environment=Development
```

and:

```text
APIErrors
Environment=Production
```

are treated as separate metric identities.

---

# Time Series

A time series is a measurement recorded repeatedly over time.

Example:

```text
ResponseTime

10:00 → 180 ms
10:01 → 210 ms
10:02 → 250 ms
10:03 → 190 ms
```

Time series allow engineers to identify:

- increases
- decreases
- spikes
- trends
- unusual behaviour

A single value shows the current measurement.

A time series shows how that measurement behaves over time.

---

# CloudWatch Statistics

CloudWatch can summarize metric data using statistics such as:

```text
Minimum
Maximum
Average
Sum
SampleCount
```

Example data:

```text
20
30
40
50
60
```

produces:

```text
Minimum = 20
Maximum = 60
Average = 40
```

Statistics make large amounts of metric data easier to analyze.

---

# CloudWatch Alarms

An alarm watches a metric and evaluates a configured condition.

Example:

```text
CPUUtilization > 80%
```

Conceptually:

```text
CPU metric
    │
    ▼
Threshold check
    │
    ├── CPU <= 80 → OK
    │
    └── CPU > 80 → ALARM
```

Alarms prevent engineers from having to continuously watch monitoring dashboards.

---

# CloudWatch Dashboards

A dashboard provides a visual overview of monitoring data.

Example:

```text
+--------------------------------+
|       Application Health       |
+--------------------------------+
| CPU             | Requests     |
| 42%             | 1,250        |
+-----------------+--------------+
| Errors          | Response     |
| 7               | 250 ms       |
+-----------------+--------------+
```

Dashboards provide a bird's-eye view of system health.

---

# First Custom Metric

Initially:

```bash
aws cloudwatch list-metrics \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

returned no custom metrics.

The first custom metric was published to:

```text
Namespace:
CloudLab/Application

Metric:
RequestCount

Value:
25

Unit:
Count
```

Command:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/Application" \
  --metric-data \
    MetricName=RequestCount,Value=25,Unit=Count \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Additional data points included:

```text
25
40
60
```

This demonstrated a metric time series.

---

# Environment Dimensions

Error metrics were separated by environment.

Development:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/Application" \
  --metric-data \
  'MetricName=ErrorCount,Dimensions=[{Name=Environment,Value=Development}],Value=3,Unit=Count' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Production:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/Application" \
  --metric-data \
  'MetricName=ErrorCount,Dimensions=[{Name=Environment,Value=Production}],Value=1,Unit=Count' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

This resulted in:

```text
ErrorCount
├── Environment=Development
└── Environment=Production
```

---

# zsh Troubleshooting

The original command:

```text
Dimensions=[{Name=Environment,Value=Development}]
```

failed with:

```text
zsh: no matches found
```

The error came from zsh rather than CloudWatch.

Square brackets have special pattern-matching meaning in zsh.

The solution was to quote the complete metric-data value:

```bash
--metric-data \
'MetricName=ErrorCount,Dimensions=[{Name=Environment,Value=Development}],Value=3,Unit=Count'
```

This caused zsh to pass the value directly to the AWS CLI.

---

# Server CPU Simulation

A custom CPU metric was used to simulate a web server.

Namespace:

```text
CloudLab/Servers
```

Metric:

```text
CPUUtilization
```

Dimension:

```text
Server=web-01
```

Example measurements:

```text
32%
51%
83%
```

This demonstrated how CloudWatch can track infrastructure measurements over time.

---

# Hands-On Challenge

A custom namespace was created:

```text
CloudLab/API
```

Three application metrics were published.

## API Requests

```text
Metric:
APIRequests

Value:
120

Unit:
Count

Dimension:
Environment=Development
```

Command:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/API" \
  --metric-data \
  'MetricName=APIRequests,Dimensions=[{Name=Environment,Value=Development}],Value=120,Unit=Count' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

## API Errors

```text
Metric:
APIErrors

Value:
7

Unit:
Count

Dimension:
Environment=Development
```

Command:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/API" \
  --metric-data \
  'MetricName=APIErrors,Dimensions=[{Name=Environment,Value=Development}],Value=7,Unit=Count' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

## Response Time

```text
Metric:
ResponseTime

Value:
250

Unit:
Milliseconds

Dimension:
Environment=Development
```

Command:

```bash
aws cloudwatch put-metric-data \
  --namespace "CloudLab/API" \
  --metric-data \
  'MetricName=ResponseTime,Dimensions=[{Name=Environment,Value=Development}],Value=250,Unit=Milliseconds' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

# Verification

Metrics were verified with:

```bash
aws cloudwatch list-metrics \
  --namespace "CloudLab/API" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Result:

```text
CloudLab/API
│
├── APIRequests
│   └── Environment=Development
│
├── APIErrors
│   └── Environment=Development
│
└── ResponseTime
    └── Environment=Development
```

The challenge was completed successfully.

---

# Infrastructure vs Application Metrics

Infrastructure metrics describe the health of infrastructure.

Examples:

```text
CPUUtilization
MemoryUsage
DiskUsage
NetworkTraffic
```

Application or business metrics describe how the application itself is performing.

Examples:

```text
ResponseTime
APIErrors
OrdersProcessed
LoginFailures
FailedPayments
```

Monitoring only infrastructure is insufficient.

For example:

```text
CPU = 30% ✅

FailedPayments = 500 ❌
```

Infrastructure may look healthy while the business application is failing.

A strong monitoring system therefore observes both.

---

# Monitoring Flow

The monitoring process can be summarized as:

```text
Resource
    ↓
Metric
    ↓
Data points
    ↓
Statistics
    ↓
Alarm
    ↓
Action
```

CloudWatch monitors numerical measurements from resources and applications.

Statistics summarize those measurements.

An alarm evaluates those statistics against configured thresholds.

If a threshold is crossed, the alarm can trigger an action or notification.

---

# Key Lessons

- CloudWatch provides monitoring and observability for AWS infrastructure and applications.
- Metrics are numerical measurements over time.
- Logs provide detailed information about events.
- Namespaces organize related metrics.
- Dimensions identify the context or resource associated with a metric.
- Different dimensions create distinct metric identities.
- A time series contains measurements across multiple timestamps.
- CloudWatch statistics include Minimum, Maximum, Average, Sum and SampleCount.
- Alarms evaluate metric conditions automatically.
- Dashboards provide a visual overview of system health.
- Infrastructure and application metrics should both be monitored.
- Shell interpretation can affect AWS CLI commands.
- zsh metric expressions containing square brackets should be quoted.

---
