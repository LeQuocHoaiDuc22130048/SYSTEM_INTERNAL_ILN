FROM python:3.11-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-real.txt .
RUN python -m pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements-real.txt

COPY real_face_ai_service.py .

ENV FACE_AI_HOST=0.0.0.0
ENV FACE_AI_PORT=5000
ENV FACE_AI_MODEL_ROOT=/models

EXPOSE 5000

CMD ["python", "real_face_ai_service.py"]
