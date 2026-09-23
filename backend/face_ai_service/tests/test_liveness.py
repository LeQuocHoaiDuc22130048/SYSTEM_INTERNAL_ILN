"""HTTP contract tests; model/decoder doubles do not demonstrate spoof detection."""

import importlib.util
import io
import json
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch


def load_service():
    # These optional native/model dependencies are unavailable in the test runtime.
    # Import the complete service; keep HTTP parsing, routing and responses real.
    insightface = types.ModuleType("insightface.app")
    insightface.FaceAnalysis = object
    dependencies = {
        "cv2": types.ModuleType("cv2"),
        "numpy": types.ModuleType("numpy"),
        "insightface": types.ModuleType("insightface"),
        "insightface.app": insightface,
    }
    path = Path(__file__).resolve().parents[1] / "real_face_ai_service.py"
    spec = importlib.util.spec_from_file_location("face_ai_under_test", path)
    module = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, dependencies):
        spec.loader.exec_module(module)
    return module


class HttpConnection:
    def __init__(self, request):
        self.input = io.BytesIO(request)
        self.output = io.BytesIO()

    def makefile(self, *args, **kwargs):
        return self.input

    def sendall(self, data):
        self.output.write(data)


class LivenessTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.service = load_service()

    def request(self, method, path, body=None):
        payload = json.dumps(body or {}).encode()
        connection = HttpConnection(
            f"{method} {path} HTTP/1.0\r\nContent-Length: {len(payload)}\r\n\r\n".encode()
            + payload
        )
        with patch.object(self.service.FaceAiHandler, "log_message"):
            self.service.FaceAiHandler(connection, ("127.0.0.1", 0), None)
        headers, response = connection.output.getvalue().split(b"\r\n\r\n", 1)
        return int(headers.split()[1]), json.loads(response)

    def test_decodable_image_cannot_pass_without_liveness_model(self):
        with patch.object(self.service, "_decode_image", return_value=object()):
            status, body = self.request("POST", "/api/v1/faces/liveness", {
                "imageBase64": "c3ludGhldGlj", "imageContentType": "image/png",
            })
        self.assertEqual(503, status)
        self.assertNotEqual(True, body.get("live"))
        self.assertNotEqual(True, body.get("isLive"))
        self.assertTrue(body.get("error"))

    def test_health_does_not_advertise_unimplemented_liveness_model(self):
        with patch.object(self.service, "_face_app", return_value=object()):
            status, body = self.request("GET", "/health")
        self.assertEqual(200, status)
        self.assertTrue(body["faceModelLoaded"])
        self.assertFalse(body["miniFasNetLoaded"])

    def test_invalid_image_still_returns_bad_request(self):
        with patch.object(self.service, "_decode_image", side_effect=ValueError("Invalid image")):
            status, body = self.request("POST", "/api/v1/faces/liveness")
        self.assertEqual(400, status)
        self.assertIn("error", body)

    def test_face_model_load_failure_still_returns_unavailable(self):
        with patch.object(self.service, "_face_app", side_effect=RuntimeError("Model unavailable")):
            status, body = self.request("GET", "/health")
        self.assertEqual(503, status)
        self.assertEqual("DOWN", body["status"])


class FallbackLivenessTest(unittest.TestCase):
    request = LivenessTest.request

    @classmethod
    def setUpClass(cls):
        path = Path(__file__).resolve().parents[1] / "simple_face_ai_service.py"
        spec = importlib.util.spec_from_file_location("fallback_under_test", path)
        cls.service = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.service)

    def test_payload_cannot_pass_without_liveness_model(self):
        status, body = self.request("POST", "/api/v1/faces/liveness", {
            "imageBase64": "c3ludGhldGlj", "imageContentType": "image/png",
        })
        self.assertEqual(503, status)
        self.assertNotEqual(True, body.get("live"))
        self.assertNotEqual(True, body.get("isLive"))
        self.assertTrue(body.get("error"))

    def test_health_does_not_advertise_missing_liveness_model(self):
        status, body = self.request("GET", "/health")
        self.assertEqual(200, status)
        self.assertFalse(body["miniFasNetLoaded"])

    def test_invalid_payload_returns_bad_request(self):
        status, body = self.request("POST", "/api/v1/faces/liveness")
        self.assertEqual(400, status)
        self.assertTrue(body.get("error"))


if __name__ == "__main__":
    unittest.main()
