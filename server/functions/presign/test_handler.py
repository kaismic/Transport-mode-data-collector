import importlib
import hashlib
import json
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

    def test_first_upload_sees_newly_activated_invite(self):
        invite = {"participant_id": "participant_001", "active": True}

        def read_invite(**kwargs):
            # Model a stale replica immediately after code activation.
            return {"Item": invite} if kwargs.get("ConsistentRead") else {}

        with (
            patch.object(self.handler, "invite_codes_table") as codes,
            patch.object(self.handler, "sessions_table") as sessions,
            patch.object(self.handler, "s3") as s3,
        ):
            codes.get_item.side_effect = read_invite
            s3.generate_presigned_url.return_value = "https://example.com/upload"
            body = _valid_body("pocket")
            body["invite_code"] = "  kais-test  "

            response = self.handler.handler({"body": json.dumps(body)}, None)

            self.assertEqual(response["statusCode"], 200)
            codes.get_item.assert_called_once_with(
                Key={"code_hash": hashlib.sha256(b"KAIS-TEST").hexdigest()},
                ConsistentRead=True,
            )
            sessions.put_item.assert_called_once()

    def test_missing_and_revoked_invites_never_issue_upload_url(self):
        for result in ({}, {"Item": {"active": False}}, {"Item": {}}):
            with (
                self.subTest(result=result),
                patch.object(self.handler, "invite_codes_table") as codes,
                patch.object(self.handler, "sessions_table") as sessions,
                patch.object(self.handler, "s3") as s3,
            ):
                codes.get_item.return_value = result

                response = self.handler.handler(
                    {"body": json.dumps(_valid_body("pocket"))}, None
                )

                self.assertEqual(response["statusCode"], 403)
                self.assertEqual(
                    json.loads(response["body"])["code"], "INVALID_INVITE_CODE"
                )
                s3.generate_presigned_url.assert_not_called()
                sessions.put_item.assert_not_called()


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
