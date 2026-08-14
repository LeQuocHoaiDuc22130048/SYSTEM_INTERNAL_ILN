"""Local development Face AI service.

This service intentionally uses only Python's standard library so it can run on
a clean developer machine. It implements the HTTP contract expected by the
Spring backend. For production, replace this service with the real face
embedding and MiniFASNet inference service.
"""

from __future__ import annotations

import base64
import json
import math
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


HOST = "127.0.0.1"
PORT = 5000
EMBEDDING_DIMENSION = 512
DEFAULT_THRESHOLD = 0.57
MAX_IMAGE_BYTES = 2_000_000


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
        length = len(raw)
    else:
        return {}

    request = json.loads(raw.decode("utf-8"))
    print(
        json.dumps(
            {
                "level": "INFO",
                "message": "Face AI request received",
                "path": handler.path,
                "contentLength": length,
                "keys": sorted(request.keys()),
                "imageContentType": request.get("imageContentType"),
            },
            separators=(",", ":"),
        ),
        flush=True,
    )
    return request


def _decode_image(request: dict[str, Any]) -> bytes:
    content_type = request.get("imageContentType")
    if content_type not in {"image/jpeg", "image/png"}:
        raise ValueError("Only image/jpeg and image/png are supported")

    image_base64 = request.get("imageBase64")
    if not isinstance(image_base64, str) or not image_base64.strip():
        raise ValueError("imageBase64 is required")

    try:
        image = base64.b64decode(image_base64, validate=True)
    except Exception as error:
        raise ValueError("imageBase64 is not valid Base64") from error

    if not image or len(image) > MAX_IMAGE_BYTES:
        raise ValueError("Image is empty or too large")
    return image


def _embedding_from_image(image: bytes) -> list[float]:
    # Local fallback is for API wiring, not real recognition. Keep embeddings
    # stable across camera frames so enrollment and verification can be tested.
    _ = image
    return [1.0] + [0.0] * (EMBEDDING_DIMENSION - 1)


def _cosine(a: list[float], b: list[float]) -> float:
    if len(a) != len(b) or not a:
        return -1.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return -1.0
    return dot / (norm_a * norm_b)


def _quality_response(image: bytes) -> dict[str, Any]:
    # This dev fallback can only validate payload shape without image libraries.
    passed = len(image) >= 1024
    return {
        "passed": passed,
        "reason": "OK" if passed else "Image payload is too small",
        "checks": {
            "singleFace": True,
            "faceSize": passed,
            "pose": True,
            "brightness": True,
            "blur": True,
        },
    }


class FaceAiHandler(BaseHTTPRequestHandler):
    server_version = "SimpleFaceAI/0.1"

    def do_GET(self) -> None:
        if self.path == "/health":
            _json_response(
                self,
                200,
                {
                    "status": "UP",
                    "modelLoaded": True,
                    "faceModelLoaded": True,
                    "miniFasNetLoaded": True,
                    "embeddingDimension": EMBEDDING_DIMENSION,
                    "implementation": "dev-stdlib-fallback",
                },
            )
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
                    {
                        "matched": score >= DEFAULT_THRESHOLD,
                        "confidence": score,
                    },
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
                        "implementation": "dev-stdlib-fallback",
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
    server = ThreadingHTTPServer((HOST, PORT), FaceAiHandler)
    print(
        json.dumps(
            {
                "level": "INFO",
                "message": "Face AI dev fallback started",
                "url": f"http://{HOST}:{PORT}",
            },
            separators=(",", ":"),
        ),
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
