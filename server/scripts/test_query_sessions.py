import sys
import unittest
from pathlib import Path


MODULE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(MODULE_DIR))

import query_sessions


class QuerySessionsParticipantFilterTests(unittest.TestCase):
    def test_allows_only_configured_three_digit_participant_ids(self):
        allowed = [
            {"participant_id": "participant_001"},
            {"participant_id": "participant_003"},
            {"participant_id": "participant_026"},
        ]
        blocked = [
            {"participant_id": "participant_002"},
            {"participant_id": "participant_26"},
            {"participant_id": "participant_026_extra"},
            {"participant_id": None},
            {},
        ]

        self.assertEqual(
            query_sessions.allowed_sync_sessions(allowed + blocked),
            allowed,
        )

    def test_list_received_sessions_filters_each_scan_page(self):
        table = FakeTable(
            [
                {
                    "Items": [
                        {
                            "session_id": "allowed-1",
                            "participant_id": "participant_001",
                        },
                        {
                            "session_id": "blocked",
                            "participant_id": "participant_002",
                        },
                    ],
                    "LastEvaluatedKey": {"page": 1},
                },
                {
                    "Items": [
                        {
                            "session_id": "allowed-2",
                            "participant_id": "participant_026",
                        }
                    ],
                },
            ]
        )

        sessions = query_sessions.list_received_sessions(table)

        self.assertEqual(
            [session["session_id"] for session in sessions],
            ["allowed-1", "allowed-2"],
        )

    def test_count_received_sessions_counts_only_allowed_participants(self):
        table = FakeTable(
            [
                {
                    "Items": [
                        {"participant_id": "participant_001"},
                        {"participant_id": "participant_999"},
                    ],
                    "LastEvaluatedKey": {"page": 1},
                },
                {
                    "Items": [
                        {"participant_id": "participant_003"},
                        {"participant_id": "participant_026"},
                    ],
                },
            ]
        )

        self.assertEqual(query_sessions.count_received_sessions(table), 3)

    def test_allows_only_configured_participant_s3_keys(self):
        self.assertTrue(
            query_sessions.is_allowed_sync_s3_key(
                "raw/participant_003/device/session.json.gz"
            )
        )
        self.assertFalse(
            query_sessions.is_allowed_sync_s3_key(
                "raw/participant_999/device/session.json.gz"
            )
        )
        self.assertFalse(
            query_sessions.is_allowed_sync_s3_key(
                "raw/participant_3/device/session.json.gz"
            )
        )
        self.assertFalse(
            query_sessions.is_allowed_sync_s3_key(
                "exports/participant_003/session.json.gz"
            )
        )


class FakeTable:
    def __init__(self, pages):
        self.pages = pages
        self.calls = 0

    def scan(self, **kwargs):
        self.calls += 1
        return self.pages[self.calls - 1]


if __name__ == "__main__":
    unittest.main()
