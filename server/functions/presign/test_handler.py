import importlib
import os
import sys
import unittest
from unittest.mock import MagicMock, patch


class HandlerValidationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.update(
            {
                "AWS_REGION": "ap-southeast-2",
                "BUCKET_NAME": "test-bucket",
                "INVITE_CODES_TABLE_NAME": "invite-codes",
                "SESSIONS_TABLE_NAME": "sessions",
            }
        )
        resource = MagicMock()
        resource.Table.return_value = MagicMock()
        with (
            patch("boto3.client", return_value=MagicMock()),
            patch("boto3.resource", return_value=resource),
        ):
            sys.modules.pop("handler", None)
            cls.handler = importlib.import_module("handler")

    def test_accepts_supported_phone_position(self):
        payload = self.handler._validate_body(_valid_body("pocket"))

        self.assertEqual(payload["phone_position"], "pocket")

    def test_rejects_unsupported_phone_position(self):
        with self.assertRaisesRegex(
            self.handler.ValidationError,
            "phone_position must be one of",
        ):
            self.handler._validate_body(_valid_body("dashboard"))


def _valid_body(phone_position):
    return {
        "invite_code": "KAIS-TEST",
        "session_id": "11111111-1111-4111-8111-111111111111",
        "device_uuid": "22222222-2222-4222-8222-222222222222",
        "vehicle_type": "car",
        "phone_position": phone_position,
        "started_at_ms": 1000,
        "stopped_at_ms": 2000,
        "trimmed_start_ms": 1000,
        "trimmed_end_ms": 2000,
        "uploaded_at_ms": 3000,
        "sensor_manifest": {},
        "sample_count": 1,
    }


if __name__ == "__main__":
    unittest.main()
