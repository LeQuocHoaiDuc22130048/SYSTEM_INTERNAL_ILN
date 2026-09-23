# Face AI Service

Local Face AI services for the attendance face-recognition contract.

## Fallback service

Use only for API wiring. It does not recognize real people.

```powershell
python .\face_ai_service\simple_face_ai_service.py
```

## Real recognition service

Install Python 3.10 or 3.11, then:

```powershell
cd D:\workspace\system_inl\application\backend
py -3.11 -m venv .venv-face-ai
.\.venv-face-ai\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r .\face_ai_service\requirements-real.txt
python .\face_ai_service\real_face_ai_service.py
```

InsightFace downloads the `buffalo_l` ONNX model on first run into
`backend\face_ai_service\models`.

To start backend with the real Face AI service:

```powershell
$env:FACE_AI_SERVICE="real"
cd D:\workspace\system_inl\application\backend
.\scripts\start-dev.ps1 -Restart
```

Endpoints:

- `GET /health`
- `POST /api/v1/faces/encode`
- `POST /api/v1/faces/verify`
- `POST /api/v1/faces/quality`
- `POST /api/v1/faces/liveness`

Neither local service implements an anti-spoof model. Both liveness endpoints
return HTTP 503 for accepted image payloads instead of claiming they are live;
invalid payloads still return HTTP 400. Health reports `miniFasNetLoaded: false`,
which the backend health check treats as unavailable. Embedding comparison at
`/verify` does not enforce liveness and is not proof of a live person.

Run the HTTP contract regression tests from the repository root:

```powershell
python -m unittest discover -s backend/face_ai_service/tests -v
```

These tests replace native/model dependencies and decoding; they do not measure
real-image anti-spoof accuracy.

Production must run the real face embedding and MiniFASNet service with HTTPS
and calibrated thresholds. Re-enroll employees after switching from fallback to
real recognition.
