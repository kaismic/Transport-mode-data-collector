import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock


MODULE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(MODULE_DIR))

import backfill_session_sync_keys


class BackfillSessionSyncKeysTests(unittest.TestCase):
    def test_confirmation_time_prefers_confirmed_at(self):
        value = backfill_session_sync_keys.confirmation_time_ms(
            {
                "confirmed_at": "2026-08-03T12:34:56.789+00:00",
                "uploaded_at_ms": 1,
            }
        )

        self.assertEqual(value, 1785760496789)

    def test_update_uses_collision_safe_composite_key(self):
        table = MagicMock()

        backfill_session_sync_keys.update_sync_fields(
            table, "session-1", 1234
        )

        values = table.update_item.call_args.kwargs[
            "ExpressionAttributeValues"
        ]
        self.assertEqual(values[":sync_key"], "0000000001234#session-1")


if __name__ == "__main__":
    unittest.main()
