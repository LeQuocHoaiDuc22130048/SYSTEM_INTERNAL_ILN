# Attendance Peak Load Test

Goal: simulate 50 employees checking attendance during the first 10 minutes of
the work day, then measure p95 latency, error rate, and CPU pressure around
face embedding verification.

Tool: [k6](https://k6.io/). Run against staging, not production.

## Fixture

Create a fixture with 50 real enrolled employees and representative face images:

```json
{
  "employees": [
    {
      "employeeId": "uuid-from-backend",
      "employeeCode": "NV001",
      "faceImageBase64": "base64-jpeg-without-data-url-prefix",
      "expectedScore": 0.9,
      "type": "IN"
    }
  ]
}
```

Use real staging embeddings and real-ish camera images. Synthetic tiny images do
not exercise face embedding/MiniFASNet inference and will hide CPU bottlenecks.

## Run

Online face-check path:

```bash
k6 run BACKEND/load-tests/attendance_peak_k6.js \
  -e BASE_URL=https://staging.example.com \
  -e ACCESS_TOKEN=... \
  -e EMPLOYEE_FIXTURE=BACKEND/load-tests/attendance_employees.staging.json \
  -e MODE=face-check
```

Offline sync path, closer to the mobile offline-first flow:

```bash
k6 run BACKEND/load-tests/attendance_peak_k6.js \
  -e BASE_URL=https://staging.example.com \
  -e ACCESS_TOKEN=... \
  -e EMPLOYEE_FIXTURE=BACKEND/load-tests/attendance_employees.staging.json \
  -e MODE=offline-sync
```

The script runs:

- 1 minute ramp-up to 10 attendance attempts/minute
- 8 minutes at 50 attendance attempts/minute
- 1 minute ramp-down

This represents 50 employees arriving during the first 10 minutes, with pressure
concentrated in the middle of the window. Increase targets if you want a more
aggressive “everyone taps at once” scenario.

Thresholds:

- `http_req_failed < 1%`
- `http_req_duration p95 < 3000ms`
- `checks > 99%`

## CPU Measurement

Measure backend and AI service separately. Face embedding inference usually
bottlenecks in the AI service CPU, not Spring itself.

Docker:

```bash
docker stats backend-container ai-container
```

Linux host:

```bash
pidstat -dur -p <backend_pid>,<ai_pid> 5
```

Kubernetes:

```bash
kubectl top pod -n staging
kubectl logs -n staging deploy/backend | jq 'select(.event=="attendance.face_check" or .event=="attendance.offline_sync")'
```

## Go-Live Gate

Do not go live until a staging run with 50 employees passes:

- p95 latency is below the agreed SLA
- server error rate is below 1%
- AI service CPU does not stay above 80-85% for the full peak window
- no queue buildup or timeout in attendance sync
- structured logs contain `request_id`, `emp_id`, `score`, `latency_ms`, and
  `result` for disputed attendance debugging

If face embedding inference CPU is saturated, reduce concurrent verification,
add an AI worker, or move inference to GPU/NNAPI/CoreML where available.
