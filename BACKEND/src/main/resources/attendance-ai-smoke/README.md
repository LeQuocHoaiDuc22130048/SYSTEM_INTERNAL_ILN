# Attendance AI smoke test fixtures

Put a small fixed fixture set here or point the environment variables to another secure folder.

Recommended files:

```text
known_good.jpg
expected_embedding.json
live.jpg
spoof.jpg
blurry.jpg
dark.jpg
```

The smoke test is enabled by default. Configure fixtures before starting the
server:

```bash
ATTENDANCE_FACE_MATCH_THRESHOLD=0.57
ATTENDANCE_FACE_CALIBRATION_FAR=0.0
ATTENDANCE_FACE_CALIBRATION_FRR=0.02
ATTENDANCE_FACE_CALIBRATION_DATASET_VERSION=company-2026-05
ATTENDANCE_FACE_CALIBRATED_AT=2026-05-30T00:00:00Z
ATTENDANCE_FACE_CALIBRATION_REPORT_PATH=/secure/calibration/face_threshold_report.json
ATTENDANCE_AI_SMOKE_TEST_ENABLED=true
ATTENDANCE_AI_SMOKE_KNOWN_GOOD=/secure/fixtures/known_good.jpg
ATTENDANCE_AI_SMOKE_EXPECTED_EMBEDDING=/secure/fixtures/expected_embedding.json
ATTENDANCE_AI_SMOKE_LIVE_IMAGE=/secure/fixtures/live.jpg
ATTENDANCE_AI_SMOKE_SPOOF_IMAGE=/secure/fixtures/spoof.jpg
ATTENDANCE_AI_SMOKE_BLURRY_IMAGE=/secure/fixtures/blurry.jpg
ATTENDANCE_AI_SMOKE_DARK_IMAGE=/secure/fixtures/dark.jpg
```

The AI service is expected to expose:

```text
POST /api/v1/faces/encode
POST /api/v1/faces/verify
POST /api/v1/faces/liveness
POST /api/v1/faces/quality
```

With `ATTENDANCE_AI_SMOKE_TEST_FAIL_FAST=true`, startup fails if any fixture
fails. This should stay enabled in production so the server never starts with a
broken face embedding/MiniFASNet/quality-gate contract.

The face match threshold must come from a real employee calibration dataset,
not from a default value. Generate the threshold report with the calibration
tool that belongs to the new model family.

Store the JSON report in a secure internal location, then set the threshold,
FAR, FRR, dataset version, calibrated timestamp, and report path from that
report before starting the backend.
