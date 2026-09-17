import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import label_session_country as labels


class FakeTable:
    name = "TransportSessions"

    def __init__(self, item):
        self.item = dict(item)
        self.updates = []

    def query(self, **_kwargs):
        return {"Items": [self.item]}

    def get_item(self, **_kwargs):
        return {"Item": dict(self.item)}

    def update_item(self, **kwargs):
        self.updates.append(kwargs)
        self.item["collection_country_code"] = kwargs["ExpressionAttributeValues"][":country"]


class FakeS3:
    def __init__(self):
        self.checked = []

    def head_object(self, **kwargs):
        self.checked.append(kwargs)


def remote_item():
    return {
        "session_id": "session-1",
        "participant_id": "participant_010",
        "status": "received",
        "s3_key": "raw/participant_010/device-a/session-1.json.gz",
        "uploaded_at_ms": 1234,
    }


class CountryLabelTests(unittest.TestCase):
    def test_cli_adapter_uses_conditional_update_and_decodes_inventory(self):
        table = labels.CliTable("TransportSessions", "ap-southeast-2")
        item = remote_item()
        encoded = {
            key: ({"N": str(value)} if isinstance(value, int) else {"S": value})
            for key, value in item.items()
        }
        with mock.patch.object(table, "call", return_value={"Items": [encoded]}) as call:
            self.assertEqual(table.participant_sessions("participant_010"), [item])
            self.assertIn("participant-id-index", call.call_args.args)
        with mock.patch.object(table, "call", return_value={}) as call:
            table.update_country(item, "participant_010", "KR")
            args = call.call_args.args
            condition = args[args.index("--condition-expression") + 1]
            self.assertIn("attribute_not_exists(collection_country_code)", condition)
            self.assertIn("uploaded_at_ms = :uploaded", condition)

    def test_inventory_checks_local_payload_and_remote_object_then_apply_is_repeatable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            item = remote_item()
            payload = root.joinpath(*Path(item["s3_key"]).parts)
            payload.parent.mkdir(parents=True)
            payload.write_bytes(b"payload")
            payload.with_suffix(f"{payload.suffix}.metadata.json").write_text(
                json.dumps(item), encoding="utf-8"
            )
            table, s3 = FakeTable(item), FakeS3()
            manifest = labels.inventory(table, s3, "bucket", "participant_010", "KR", root)
            self.assertEqual(len(manifest["sessions"]), 1)
            self.assertEqual(labels.apply_manifest(table, s3, manifest), 1)
            self.assertEqual(labels.apply_manifest(table, s3, manifest), 1)
            self.assertEqual(labels.verify_manifest(table, manifest), 1)
            self.assertEqual(table.item["collection_country_code"], "KR")
            self.assertEqual(len(s3.checked), 3)
            self.assertIn("ConditionExpression", table.updates[0])

    def test_changed_remote_metadata_is_rejected_before_update(self):
        table, s3 = FakeTable(remote_item()), FakeS3()
        manifest = {
            "schema_version": 1,
            "table": table.name,
            "bucket": "bucket",
            "participant_id": "participant_010",
            "collection_country_code": "KR",
            "sessions": [{"session_id": "session-1", "s3_key": "different",
                          "uploaded_at_ms": 1234}],
        }
        with self.assertRaisesRegex(ValueError, "metadata changed"):
            labels.apply_manifest(table, s3, manifest)
        self.assertEqual(table.updates, [])


if __name__ == "__main__":
    unittest.main()
