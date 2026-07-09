import sys
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(MODULE_DIR))

import download_sessions


class DownloadSessionsConfigTests(unittest.TestCase):
    def test_sync_new_config_calls_existing_download_behavior(self):
        config = {
            "bucket": "test-bucket",
            "table": "TestSessions",
            "sync-new": True,
            "output-dir": "downloads",
            "since-ms": 123,
            "decompress": True,
            "overwrite": True,
        }

        with patch.object(
            download_sessions.query_sessions,
            "sync_new_sessions",
            return_value={"total_downloaded_count": 1},
        ) as sync_new_sessions:
            result = download_sessions.run_from_config(config)

        self.assertEqual(result, {"total_downloaded_count": 1})
        sync_new_sessions.assert_called_once_with(
            bucket="test-bucket",
            table="TestSessions",
            output_dir=Path("downloads"),
            checkpoint_file=Path("downloads") / ".download_checkpoint.json",
            since_ms=123,
            decompress=True,
            overwrite=True,
        )

    def test_download_s3_key_config_calls_existing_single_download_behavior(self):
        config = {
            "bucket": "test-bucket",
            "download-s3-key": "raw/participant_001/device/session.json.gz",
        }

        with patch.object(
            download_sessions.query_sessions,
            "load_session",
            return_value={"session_id": "session-1"},
        ) as load_session:
            result = download_sessions.run_from_config(config)

        self.assertEqual(result, {"session_id": "session-1"})
        load_session.assert_called_once_with(
            "test-bucket",
            "raw/participant_001/device/session.json.gz",
        )

    def test_requires_download_mode(self):
        with self.assertRaisesRegex(ValueError, "sync-new"):
            download_sessions.run_from_config({"bucket": "test-bucket"})


if __name__ == "__main__":
    unittest.main()
