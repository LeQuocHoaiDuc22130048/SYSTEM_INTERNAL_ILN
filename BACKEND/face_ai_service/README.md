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

Production must run the real face embedding and MiniFASNet service with HTTPS
and calibrated thresholds. Re-enroll employees after switching from fallback to
real recognition.
