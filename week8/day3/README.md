# Week 8 Day 3 — CloudWatch Logs & Log Analysis

## Objective

Learn how CloudWatch Logs can be used to collect, organize, search, filter, and investigate application logs during incidents.

The lab focused on:

- log groups
- log streams
- log events
- log levels
- request IDs
- log filtering
- retention policies
- structured logging
- incident investigation
- connecting metrics with logs
- troubleshooting AWS CLI log commands

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

# Why Logs Matter

Metrics can tell us that something is wrong.

For example:

```text
ResponseTime = high
ErrorCount   = high
```

But metrics do not always explain why.

Logs provide detailed event information.

Example:

```text
ERROR request_id=req-001 database connection timeout
```

A useful mental model is:

```text
Metric
→ Something looks wrong

Log
→ This is what actually happened
```

---

# CloudWatch Logs Structure

CloudWatch Logs uses three main concepts:

```text
Log Group
   ↓
Log Stream
   ↓
Log Events
```

---

## Log Group

A log group contains related log streams.

Example:

```text
/cloudlab/payment-api
```

A log group can represent one application or service.

---

## Log Stream

A log stream contains a sequence of log events from one source.

Example:

```text
payment-api-01
payment-api-02
```

These can represent different:

- application instances
- containers
- servers
- processes

Using separate streams helps identify which source generated a problem.

---

## Log Event

A log event is one individual timestamped message.

Example:

```text
ERROR request_id=pay-001 payment gateway timeout
```

---

# Log Levels

Common log levels include:

```text
DEBUG
INFO
WARN
ERROR
```

### DEBUG

Detailed troubleshooting or development information.

### INFO

Normal application behavior.

Example:

```text
INFO payment request received
```

### WARN

Something unusual happened, but the application may continue.

Example:

```text
WARN payment gateway slow duration_ms=1200
```

### ERROR

An operation failed and needs investigation.

Example:

```text
ERROR payment gateway timeout
```

An ERROR does not necessarily mean the entire application has crashed.

---

# Creating the Checkout API Log Group

A log group was created:

```text
/cloudlab/checkout-api
```

Command:

```bash
aws logs create-log-group \
  --log-group-name "$LOG_GROUP" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

# Creating Log Streams

Streams were created for separate application sources:

```text
checkout-api-dev-01
checkout-api-dev-02
```

Commands:

```bash
aws logs create-log-stream \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

and:

```bash
aws logs create-log-stream \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM_2" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

# Log Event Timestamps

CloudWatch Logs uses Unix epoch timestamps in milliseconds.

On macOS:

```bash
export LOG_TIME=$(($(date +%s) * 1000))
```

Example:

```text
1791390000000
```

---

# Publishing Log Events

A log event was published using:

```bash
aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events \
  timestamp="$LOG_TIME",message="INFO checkout-api application started" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

# Request IDs

A request ID was added to related events.

Example:

```text
request_id=req-001
```

This allows all events belonging to one request to be traced together.

Example request lifecycle:

```text
INFO request started
INFO connecting to database
ERROR database timeout
ERROR status=500
```

All of these can be associated with:

```text
request_id=req-001
```

---

# Reading a Known Stream

`get-log-events` was used when the exact stream was already known.

Example:

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

This answers:

```text
Show me the events from this specific source.
```

---

# Filtering Logs

`filter-log-events` allows searching the whole log group.

Example:

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "ERROR" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

This avoids manually reading every log entry.

---

# Filtering by Request ID

Logs associated with a specific request were found using:

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "req-001" \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

This makes request IDs valuable during troubleshooting.

---

# Filtering Specific Errors

A specific failure could be searched directly.

Example:

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"database connection timeout"' \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

---

# Retention Policies

A retention policy determines how long logs remain stored.

For this lab:

```text
7 days
```

Command:

```bash
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 7 \
  --endpoint-url "$AWS_ENDPOINT_URL"
```

Retention policies help:

- remove stale logs
- reduce storage usage
- control cost
- enforce data retention requirements

---

# Development vs Audit Log Retention

Development logs may have shorter retention because they are mainly useful during active troubleshooting.

Example:

```text
Development logs
→ 7 days
```

Security or audit logs may need to remain much longer.

Example:

```text
Audit logs
→ months or years
```

depending on operational and compliance requirements.

---

# Structured Logging

Plain-text logging:

```text
ERROR request_id=pay-001 payment gateway timeout
```

Structured logging:

```json
{
  "level": "ERROR",
  "service": "payment-api",
  "request_id": "pay-001",
  "error": "payment gateway timeout",
  "status": 503
}
```

Structured logs are easier for software to:

- parse
- search
- filter
- aggregate
- analyze automatically

Fields can be queried directly rather than extracting information from arbitrary text.

---

# Hands-On Payment Incident Challenge

The following log group was created:

```text
/cloudlab/payment-api
```

Two application streams were created:

```text
payment-api-01
payment-api-02
```

The final structure was:

```text
/cloudlab/payment-api
│
├── payment-api-01
└── payment-api-02
```

Both streams were successfully created and verified.

---

# payment-api-01 Incident

The first stream simulated a failing payment request.

Events:

```text
INFO request_id=pay-001 payment request received

WARN request_id=pay-001 payment gateway slow duration_ms=1200

ERROR request_id=pay-001 payment gateway timeout

ERROR request_id=pay-001 payment failed status=503
```

The request showed a clear failure progression:

```text
Request received
       ↓
Gateway became slow
       ↓
Gateway timed out
       ↓
Payment failed
       ↓
HTTP 503
```

The events were successfully published to `payment-api-01`.

---

# payment-api-02 Healthy Request

The second stream simulated a successful request.

Events:

```text
INFO request_id=pay-002 payment request received

INFO request_id=pay-002 payment completed status=200 duration_ms=190
```

The request completed successfully with:

```text
status=200
duration=190 ms
```

No WARN or ERROR events were produced for the tested request.

---

# Request ID Investigation

Filtering:

```text
pay-001
```

returned all events associated with the failed request.

The complete sequence was:

```text
INFO payment request received

WARN payment gateway slow duration_ms=1200

ERROR payment gateway timeout

ERROR payment failed status=503
```

This demonstrates how request IDs allow engineers to reconstruct the lifecycle of a request.

---

# ERROR Filtering

The log group was filtered using:

```text
ERROR
```

This returned:

```text
ERROR request_id=pay-001 payment gateway timeout

ERROR request_id=pay-001 payment failed status=503
```

Both errors were produced by:

```text
payment-api-01
```

This avoided reading unrelated INFO events.

---

# Exact Error Search

The specific phrase:

```text
payment gateway timeout
```

was searched and successfully returned the corresponding event.

This demonstrated how filtering can isolate a known failure message.

---

# Incident Analysis

The logs suggest that the failing dependency was the:

```text
Payment Gateway
```

The evidence was:

```text
gateway slow
       ↓
gateway timeout
       ↓
payment failed
```

The stream itself was not the root cause.

`payment-api-01` was where the problem was observed.

The likely failing dependency was the external/internal payment gateway being called by the application.

---

# Metrics and Logs Together

Metrics and logs serve different but complementary purposes.

Metrics answer:

```text
When did something abnormal happen?
How much did it change?
```

Logs answer:

```text
What exactly happened?
Which request failed?
Which dependency was involved?
```

Combined workflow:

```text
Metric spike
    ↓
Identify timestamp
    ↓
Search logs near that time
    ↓
Find request ID
    ↓
Trace request
    ↓
Identify failed dependency
    ↓
Investigate root cause
```

---

# Example Incident Investigation

Imagine CloudWatch shows:

```text
ResponseTime = 1200 ms
ErrorCount   = high
```

The next steps would be:

```text
Find timestamp
      ↓
Search logs
      ↓
Find pay-001
      ↓
Observe gateway slowdown
      ↓
Observe timeout
      ↓
Observe HTTP 503
      ↓
Investigate payment gateway
```

This is how monitoring transitions into troubleshooting.

---

# AWS CLI Troubleshooting Lessons

Several useful AWS CLI mistakes were encountered during the challenge.

Incorrect:

```bash
aws log ...
```

Correct:

```bash
aws logs ...
```

Incorrect:

```bash
aws logs describe-log-group
```

Correct:

```bash
aws logs describe-log-groups
```

Incorrect attempt to create two streams in one `--log-stream-name` value resulted in one stream whose name contained both values.

The incorrect stream was deleted using:

```bash
aws logs delete-log-stream
```

The two intended streams were then created separately.

Another CLI lesson:

Incorrect:

```bash
--log-stream-name
```

for `filter-log-events`

Correct plural option:

```bash
--log-stream-names
```

These mistakes reinforced the importance of using:

```bash
aws logs help
```

and:

```bash
aws logs <command> help
```

when troubleshooting AWS CLI syntax.

---

# Key Lessons

- Log groups organize related streams.
- Log streams represent individual log sources.
- Log events are individual timestamped messages.
- INFO represents normal activity.
- WARN represents unusual but potentially recoverable conditions.
- ERROR represents failed operations requiring investigation.
- Request IDs allow events from one request to be traced together.
- `get-log-events` reads a known stream.
- `filter-log-events` searches log data.
- Filtering reduces noise during incident investigation.
- Retention policies control how long logs are stored.
- Structured logs are easier for software to analyze.
- Metrics reveal abnormal behavior.
- Logs explain what happened.
- Timestamps connect metrics and logs during troubleshooting.
- The payment incident suggested a payment gateway failure rather than an application-instance failure.

---