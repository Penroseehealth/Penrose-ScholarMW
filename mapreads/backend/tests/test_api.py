import base64
import os
import struct
import tempfile
import unittest
import zlib
from unittest.mock import patch

from fastapi.testclient import TestClient

from backend.app.main import app


def _png_data_url() -> str:
    def chunk(kind: bytes, content: bytes) -> bytes:
        crc = zlib.crc32(kind + content) & 0xFFFFFFFF
        return struct.pack(">I", len(content)) + kind + content + struct.pack(">I", crc)

    image = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00"))
        + chunk(b"IEND", b"")
    )
    return "data:image/png;base64," + base64.b64encode(image).decode("ascii")


class MapReadsApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.environment = patch.dict(
            os.environ,
            {"MAPREADS_DB_PATH": os.path.join(self.temporary_directory.name, "test.sqlite3")},
        )
        self.environment.start()
        self.client_context = TestClient(app)
        self.client = self.client_context.__enter__()

    def tearDown(self) -> None:
        self.client_context.__exit__(None, None, None)
        self.environment.stop()
        self.temporary_directory.cleanup()

    def test_health_and_generation_validation(self) -> None:
        self.assertEqual(self.client.get("/api/health").json()["status"], "ok")
        response = self.client.post(
            "/api/maps/generate",
            json={
                "config": {
                    "seed": 12,
                    "hills": 4,
                    "terrain": "mixed",
                    "complexity": 3,
                    "palette": "elevation",
                    "indexColor": "#7d2838",
                    "layers": {"rivers": False, "schools": True},
                }
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["renderer"], "javascript-smartboard")
        self.assertEqual(response.json()["config"]["seed"], 12)
        self.assertEqual(response.json()["config"]["complexity"], 3)
        self.assertEqual(response.json()["config"]["palette"], "elevation")
        self.assertEqual(response.json()["config"]["indexColor"], "#7d2838")
        self.assertFalse(response.json()["config"]["layers"]["rivers"])
        invalid = self.client.post(
            "/api/maps/generate",
            json={"config": {"hills": 12, "terrain": "ocean"}},
        )
        self.assertEqual(invalid.status_code, 422)
        invalid_color = self.client.post(
            "/api/maps/generate",
            json={"config": {"indexColor": "not-a-color"}},
        )
        self.assertEqual(invalid_color.status_code, 422)

    def test_map_library_crud_persists_config_and_annotations(self) -> None:
        payload = {
            "name": "North ridge practice",
            "config": {"seed": 31, "terrain": "mixed"},
            "annotations": [{"t": "mark", "x": 20, "y": 45}],
        }
        created = self.client.post("/api/maps", json=payload)
        self.assertEqual(created.status_code, 201)
        map_id = created.json()["id"]
        loaded = self.client.get(f"/api/maps/{map_id}").json()
        self.assertEqual(loaded["annotations"], payload["annotations"])
        self.assertEqual(loaded["config"]["terrain"], "mixed")
        self.assertEqual(len(self.client.get("/api/maps").json()), 1)

        updated = self.client.put(
            f"/api/maps/{map_id}",
            json={**payload, "name": "Updated ridge"},
        )
        self.assertEqual(updated.json()["name"], "Updated ridge")
        self.assertEqual(self.client.delete(f"/api/maps/{map_id}").status_code, 204)
        self.assertEqual(self.client.get(f"/api/maps/{map_id}").status_code, 404)

    def test_blank_map_names_are_rejected(self) -> None:
        response = self.client.post(
            "/api/maps",
            json={"name": "  ", "config": {}, "annotations": []},
        )
        self.assertEqual(response.status_code, 422)

    def test_map_calculations(self) -> None:
        distance = self.client.post(
            "/api/calculations",
            json={
                "kind": "distance",
                "a": {"x": 0, "y": 0},
                "b": {"x": 300, "y": 400},
                "scale": 50000,
            },
        )
        self.assertEqual(distance.json()["result"]["ground_metres"], 500)
        self.assertEqual(distance.json()["result"]["map_centimetres"], 1)
        bearing = self.client.post(
            "/api/calculations",
            json={
                "kind": "bearing",
                "a": {"x": 0, "y": 0},
                "b": {"x": 1, "y": 1},
            },
        )
        self.assertEqual(bearing.json()["result"]["degrees"], 45)
        missing_point = self.client.post(
            "/api/calculations",
            json={"kind": "distance", "a": {"x": 0, "y": 0}},
        )
        self.assertEqual(missing_point.status_code, 422)

    def test_png_export_is_persisted_and_downloadable(self) -> None:
        created = self.client.post(
            "/api/maps",
            json={"name": "Export map", "config": {}, "annotations": []},
        ).json()
        exported = self.client.post(
            f"/api/maps/{created['id']}/exports/png",
            json={"data_url": _png_data_url()},
        )
        self.assertEqual(exported.status_code, 201)
        downloaded = self.client.get(exported.json()["download_url"])
        self.assertEqual(downloaded.status_code, 200)
        self.assertEqual(downloaded.headers["content-type"], "image/png")
        self.assertTrue(downloaded.content.startswith(b"\x89PNG\r\n\x1a\n"))

        invalid = self.client.post(
            f"/api/maps/{created['id']}/exports/png",
            json={"data_url": "data:image/png;base64,SGVsbG8gV29ybGQ="},
        )
        self.assertEqual(invalid.status_code, 422)

    def test_unimplemented_learning_routes_are_explicit(self) -> None:
        questions = self.client.post("/api/questions/generate", json={"level": "msce"})
        teaching = self.client.post(
            "/api/teaching/assist",
            json={"prompt": "Explain contour spacing"},
        )
        self.assertEqual(questions.status_code, 501)
        self.assertEqual(teaching.status_code, 501)
        self.assertEqual(questions.json()["detail"]["code"], "not_implemented")


if __name__ == "__main__":
    unittest.main()
