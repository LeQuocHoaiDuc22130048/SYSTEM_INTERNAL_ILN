# Health Check And Uptime Monitor

Public endpoint:

```text
GET /health
```

Use the HTTPS production URL:

```text
https://your-domain.example/health
```

The endpoint returns HTTP `200` only when every critical check is healthy. It
returns HTTP `503` when any check is down.

Checks:

- `database`: runs `SELECT 1`
- `faceAiModel`: calls `FACE_RECOGNITION_BASE_URL + FACE_RECOGNITION_HEALTH_PATH`
- `diskSpace`: checks free disk space for `ATTENDANCE_BACKUP_DIRECTORY`
- `uptimeSeconds`: reports backend uptime since `ApplicationReadyEvent`

Configuration:

```bash
FACE_RECOGNITION_HEALTH_PATH=/health
HEALTH_DISK_MIN_FREE_BYTES=1073741824
HEALTH_DISK_MIN_FREE_RATIO=0.10
```

## UptimeRobot

1. Create monitor: `HTTPS`
2. URL: `https://your-domain.example/health`
3. Monitoring interval: `1 minute`
4. Alert contacts: Telegram and email
5. Expected status: any `2xx` is up; `503` or timeout is down

## Better Uptime

1. Create monitor: `URL monitor`
2. URL: `https://your-domain.example/health`
3. Check frequency: `1 minute`
4. Escalation policy: Telegram first, email fallback
5. Consider incident when status code is not `2xx` or response times out

The AI service should expose its own `/health` endpoint and include model status
fields when possible, for example:

```json
{
  "status": "UP",
  "modelLoaded": true,
  "faceModelLoaded": true,
  "miniFasNetLoaded": true
}
```

If any model loaded flag is `false`, the backend `/health` reports `DOWN`.
