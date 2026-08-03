import importlib.util
import json
import os
import sys
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import MagicMock, patch


MODULE_PATH = Path(__file__).with_name("handler.py")


class ConfirmHandlerTests(unittest.TestCase):
    def setUp(self):
        os.environ["SESSIONS_TABLE_NAME"] = "sessions"
        self.table = MagicMock()
        self.table.update_item.return_value = {
            "Attributes": {"session_id": "session-1", "status": "received"}
        }
        resource = MagicMock()
        resource.Table.return_value = self.table
        with patch("boto3.resource", return_value=resource):
            spec = importlib.util.spec_from_file_location("confirm_handler_test", MODULE_PATH)
            self.handler = importlib.util.module_from_spec(spec)
            sys.modules[spec.name] = self.handler
            spec.loader.exec_module(self.handler)

    def tearDown(self):
        sys.modules.pop("confirm_handler_test", None)

    def test_confirmation_adds_ordered_sync_attributes(self):
        event = {
            "body": json.dumps(
                {"session_id": "session-1", "uploaded_at_ms": 1234}
            )
        }
        fixed_now = datetime.fromisoformat("2026-08-03T12:34:56.789+00:00")

        with patch.object(self.handler, "datetime") as datetime_mock:
            datetime_mock.now.return_value = fixed_now
            response = self.handler.handler(event, None)

        self.assertEqual(response["statusCode"], 200)
        values = self.table.update_item.call_args.kwargs[
            "ExpressionAttributeValues"
        ]
        self.assertEqual(values[":confirmed_at_ms"], 1785760496789)
        self.assertEqual(values[":sync_partition"], "received")
        self.assertEqual(
            values[":sync_key"], "1785760496789#session-1"
        )


if __name__ == "__main__":
    unittest.main()
