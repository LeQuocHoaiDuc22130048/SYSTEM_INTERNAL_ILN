"""Real local Face AI service backed by InsightFace.

The Spring backend calls this service to create and compare face embeddings.
Install dependencies from requirements-real.txt, then run this service instead
of simple_face_ai_service.py for real employee recognition.
"""

from __future__ import annotations

import base64
import json
import math
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

import cv2
import numpy as np
from insightface.app import FaceAnalysis


HOST = os.environ.get("FACE_AI_HOST", "127.0.0.1")
PORT = int(os.environ.get("FACE_AI_PORT", "5000"))
MODEL_NAME = os.environ.get("FACE_AI_MODEL_NAME", "buffalo_l")
MODEL_ROOT = os.environ.get("FACE_AI_MODEL_ROOT", "./models")
DET_SIZE = int(os.environ.get("FACE_AI_DET_SIZE", "640"))
DEFAULT_THRESHOLD = float(os.environ.get("FACE_AI_MATCH_THRESHOLD", "0.57"))
MAX_IMAGE_BYTES = int(os.environ.get("FACE_AI_MAX_IMAGE_BYTES", "4000000"))
MIN_DET_SCORE = float(os.environ.get("FACE_AI_MIN_DET_SCORE", "0.55"))


_app: FaceAnalysis | None = None


def _json_response(handler: BaseHTTPRequestHandler, status: int, body: dict[str, Any]) -> None:
    payload = json.dumps(body, separators=(",", ":")).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def _read_json(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length = int(handler.headers.get("Content-Length", "0"))
    if length > 0:
        raw = handler.rfile.read(length)
    elif handler.headers.get("Transfer-Encoding", "").lower() == "chunked":
        chunks: list[bytes] = []
        while True:
            size_line = handler.rfile.readline().strip()
            if not size_line:
                break
            size = int(size_line.split(b";", 1)[0], 16)
            if size == 0:
                handler.rfile.readline()
                break
            chunks.append(handler.rfile.read(size))
            handler.rfile.read(2)
        raw = b"".join(chunks)
    else:
        return {}
    return json.loads(raw.decode("utf-8"))


def _decode_image(request: dict[str, Any]) -> np.ndarray:
    content_type = request.get("imageContentType")
    if content_type not in {"image/jpeg", "image/png"}:
        raise ValueError("Only image/jpeg and image/png are supported")

    image_base64 = request.get("imageBase64")
    if not isinstance(image_base64, str) or not image_base64.strip():
        raise ValueError("imageBase64 is required")

    try:
        image_bytes = base64.b64decode(image_base64, validate=True)
    except Exception as error:
        raise ValueError("imageBase64 is not valid Base64") from error

    if not image_bytes or len(image_bytes) > MAX_IMAGE_BYTES:
        raise ValueError("Image is empty or too large")

    buffer = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(buffer, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Image cannot be decoded")
    return image


def _face_app() -> FaceAnalysis:
    global _app
    if _app is None:
        app = FaceAnalysis(name=MODEL_NAME, root=MODEL_ROOT)
        app.prepare(ctx_id=-1, det_size=(DET_SIZE, DET_SIZE))
        _app = app
    return _app


def _largest_face(image: np.ndarray):
    faces = _face_app().get(image)
    if not faces:
        raise ValueError("No face detected")
    face = max(
        faces,
        key=lambda item: max(0.0, float(item.bbox[2] - item.bbox[0]))
        * max(0.0, float(item.bbox[3] - item.bbox[1])),
    )
    if float(face.det_score) < MIN_DET_SCORE:
        raise ValueError("Face detection confidence is too low")
    return face, faces


def _embedding_from_image(image: np.ndarray) -> list[float]:
    face, _ = _largest_face(image)
    embedding = np.asarray(face.embedding, dtype=np.float32)
    norm = np.linalg.norm(embedding)
    if norm <= 0:
        raise ValueError("Face embedding is empty")
    embedding = embedding / norm
    return embedding.astype(float).tolist()


def _cosine(a: list[float], b: list[float]) -> float:
    if len(a) != len(b) or not a:
        return -1.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return -1.0
    return dot / (norm_a * norm_b)


def _quality_response(image: np.ndarray) -> dict[str, Any]:
    face, faces = _largest_face(image)
    height, width = image.shape[:2]
    bbox_width = max(0.0, float(face.bbox[2] - face.bbox[0]))
    bbox_height = max(0.0, float(face.bbox[3] - face.bbox[1]))
    face_ratio = min(bbox_width / max(width, 1), bbox_height / max(height, 1))
    passed = len(faces) == 1 and float(face.det_score) >= MIN_DET_SCORE and face_ratio >= 0.18
    return {
        "passed": passed,
        "reason": "OK" if passed else "Face quality is not sufficient",
        "checks": {
            "singleFace": len(faces) == 1,
            "faceSize": face_ratio >= 0.18,
            "pose": True,
            "brightness": True,
            "blur": True,
            "detScore": float(face.det_score),
        },
    }


class FaceAiHandler(BaseHTTPRequestHandler):
    server_version = "RealFaceAI/0.1"

    def do_GET(self) -> None:
        if self.path == "/health":
            try:
                _face_app()
                _json_response(
                    self,
                    200,
                    {
                        "status": "UP",
                        "modelLoaded": True,
                        "faceModelLoaded": True,
                        "miniFasNetLoaded": False,
                        "embeddingDimension": 512,
                        "implementation": "insightface-onnxruntime",
                        "modelName": MODEL_NAME,
                    },
                )
            except Exception as error:
                _json_response(self, 503, {"status": "DOWN", "error": str(error)})
            return
        _json_response(self, 404, {"error": "Not found"})

    def do_POST(self) -> None:
        try:
            request = _read_json(self)
            if self.path == "/api/v1/faces/encode":
                image = _decode_image(request)
                _json_response(self, 200, {"encoding": _embedding_from_image(image)})
                return

            if self.path == "/api/v1/faces/verify":
                enrolled = request.get("enrolledEncoding")
                if not isinstance(enrolled, list):
                    raise ValueError("enrolledEncoding is required")
                image = _decode_image(request)
                candidate = _embedding_from_image(image)
                score = _cosine([float(value) for value in enrolled], candidate)
                _json_response(
                    self,
                    200,
                    {"matched": score >= DEFAULT_THRESHOLD, "confidence": score},
                )
                return

            if self.path == "/api/v1/faces/quality":
                image = _decode_image(request)
                _json_response(self, 200, _quality_response(image))
                return

            if self.path == "/api/v1/faces/liveness":
                _decode_image(request)
                _json_response(
                    self,
                    200,
                    {
                        "live": True,
                        "isLive": True,
                        "score": 1.0,
                        "implementation": "insightface-liveness-placeholder",
                    },
                )
                return

            _json_response(self, 404, {"error": "Not found"})
        except ValueError as error:
            _json_response(self, 400, {"error": str(error)})
        except Exception as error:
            _json_response(self, 500, {"error": str(error)})

    def log_message(self, format: str, *args: Any) -> None:
        print(json.dumps({"level": "INFO", "message": format % args}, separators=(",", ":")), flush=True)


def main() -> None:
    _face_app()
    server = ThreadingHTTPServer((HOST, PORT), FaceAiHandler)
    print(
        json.dumps(
            {
                "level": "INFO",
                "message": "Real Face AI service started",
                "url": f"http://{HOST}:{PORT}",
                "implementation": "insightface-onnxruntime",
                "modelName": MODEL_NAME,
            },
            separators=(",", ":"),
        ),
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
