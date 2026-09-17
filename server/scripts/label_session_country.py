"""Inventory and conditionally label a reviewed set of collector sessions."""

import argparse
import json
import re
import subprocess
from pathlib import Path

import boto3
from boto3.dynamodb.conditions import Attr, Key
from boto3.dynamodb.types import TypeDeserializer


COUNTRY_CODE = re.compile(r"^[A-Z]{2}$")


class CliTable:
    """DynamoDB adapter for AWS CLI login credentials unavailable to boto3."""

    def __init__(self, name, region):
        self.name = name
        self.region = region
        self.deserializer = TypeDeserializer()

    def call(self, *arguments):
        result = subprocess.run(
            ["aws", *arguments, "--region", self.region, "--output", "json"],
            capture_output=True, text=True,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or "AWS CLI command failed")
        return json.loads(result.stdout) if result.stdout.strip() else {}

    def decode(self, item):
        return {key: self.deserializer.deserialize(value) for key, value in item.items()}

    def participant_sessions(self, participant_id):
        items = []
        args = ["dynamodb", "query", "--table-name", self.name,
                "--index-name", "participant-id-index",
                "--key-condition-expression", "participant_id = :participant",
                "--expression-attribute-values",
                json.dumps({":participant": {"S": participant_id}}),
                "--no-paginate"]
        start_key = None
        while True:
            page = self.call(*args, *(["--exclusive-start-key", json.dumps(start_key)]
                                      if start_key else []))
            items.extend(self.decode(item) for item in page.get("Items", []))
            start_key = page.get("LastEvaluatedKey")
            if not start_key:
                return sorted(items, key=lambda item: item["session_id"])

    def get_item(self, *, Key, ConsistentRead):
        args = ["dynamodb", "get-item", "--table-name", self.name,
                "--key", json.dumps({"session_id": {"S": Key["session_id"]}})]
        if ConsistentRead:
            args.append("--consistent-read")
        page = self.call(*args)
        return {"Item": self.decode(page["Item"])} if "Item" in page else {}

    def update_country(self, row, participant_id, country_code):
        values = {
            ":country": {"S": country_code},
            ":participant": {"S": participant_id},
            ":received": {"S": "received"},
            ":s3": {"S": row["s3_key"]},
            ":uploaded": {"N": str(row["uploaded_at_ms"])},
        }
        self.call(
            "dynamodb", "update-item", "--table-name", self.name,
            "--key", json.dumps({"session_id": {"S": row["session_id"]}}),
            "--update-expression", "SET collection_country_code = :country",
            "--condition-expression",
            "participant_id = :participant AND #status = :received AND "
            "s3_key = :s3 AND uploaded_at_ms = :uploaded AND "
            "(attribute_not_exists(collection_country_code) OR "
            "collection_country_code = :country)",
            "--expression-attribute-names", json.dumps({"#status": "status"}),
            "--expression-attribute-values", json.dumps(values),
        )


class CliS3:
    def __init__(self, table):
        self.table = table

    def head_object(self, *, Bucket, Key):
        self.table.call("s3api", "head-object", "--bucket", Bucket, "--key", Key)


def participant_sessions(table, participant_id):
    if isinstance(table, CliTable):
        return table.participant_sessions(participant_id)
    items = []
    query = {
        "IndexName": "participant-id-index",
        "KeyConditionExpression": Key("participant_id").eq(participant_id),
    }
    while True:
        page = table.query(**query)
        items.extend(page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            return sorted(items, key=lambda item: item["session_id"])
        query["ExclusiveStartKey"] = page["LastEvaluatedKey"]


def local_sessions(output_dir, participant_id):
    root = output_dir / "raw" / participant_id
    result = {}
    for path in root.rglob("*.json.gz.metadata.json"):
        item = json.loads(path.read_text(encoding="utf-8"))
        session_id = item["session_id"]
        if session_id in result or item.get("participant_id") != participant_id:
            raise ValueError(f"Duplicate or mismatched local session: {path}")
        payload = output_dir.joinpath(*Path(item["s3_key"]).parts)
        if not payload.is_file() or path != payload.with_suffix(
            f"{payload.suffix}.metadata.json"
        ):
            raise ValueError(f"Missing or mismatched local payload: {path}")
        result[session_id] = item
    return result


def inventory(table, s3, bucket, participant_id, country_code, output_dir):
    if not COUNTRY_CODE.fullmatch(country_code):
        raise ValueError("country code must be two uppercase letters")
    local = local_sessions(output_dir, participant_id)
    remote = participant_sessions(table, participant_id)
    if not remote:
        raise ValueError(f"No remote sessions for {participant_id}")
    rows = []
    for indexed in remote:
        session_id = indexed["session_id"]
        item = table.get_item(Key={"session_id": session_id}, ConsistentRead=True).get("Item")
        if item is None or item.get("status") != "received":
            raise ValueError(f"Session is absent or not received: {session_id}")
        if item.get("participant_id") != participant_id:
            raise ValueError(f"Participant changed for {session_id}")
        if item.get("collection_country_code") not in (None, country_code):
            raise ValueError(f"Conflicting country label for {session_id}")
        local_item = local.get(session_id)
        if (local_item is None
                or local_item.get("s3_key") != item.get("s3_key")
                or local_item.get("status") != "received"
                or int(local_item.get("uploaded_at_ms", -1)) != int(item["uploaded_at_ms"])):
            raise ValueError(f"Missing or mismatched local session: {session_id}")
        s3.head_object(Bucket=bucket, Key=item["s3_key"])
        rows.append({
            "session_id": session_id,
            "s3_key": item["s3_key"],
            "uploaded_at_ms": int(item["uploaded_at_ms"]),
        })
    if set(local) != {row["session_id"] for row in rows}:
        raise ValueError("Remote and local participant inventories differ")
    return {
        "schema_version": 1,
        "table": table.name,
        "bucket": bucket,
        "participant_id": participant_id,
        "collection_country_code": country_code,
        "sessions": rows,
    }


def apply_manifest(table, s3, manifest):
    if manifest.get("schema_version") != 1 or manifest.get("table") != table.name:
        raise ValueError("Manifest schema or table does not match")
    participant_id = manifest["participant_id"]
    country_code = manifest["collection_country_code"]
    if not COUNTRY_CODE.fullmatch(country_code):
        raise ValueError("Invalid country code")
    rows = manifest["sessions"]
    if not rows or len({row["session_id"] for row in rows}) != len(rows):
        raise ValueError("Manifest must contain unique sessions")
    # Validate the complete reviewed set before updating any row.
    for row in rows:
        session_id = row["session_id"]
        item = table.get_item(Key={"session_id": session_id}, ConsistentRead=True).get("Item")
        if (item is None or item.get("participant_id") != participant_id
                or item.get("status") != "received"
                or item.get("s3_key") != row["s3_key"]
                or int(item.get("uploaded_at_ms", -1)) != row["uploaded_at_ms"]
                or item.get("collection_country_code") not in (None, country_code)):
            raise ValueError(f"Remote metadata changed for {session_id}")
        s3.head_object(Bucket=manifest["bucket"], Key=row["s3_key"])
    updated = 0
    for row in rows:
        if isinstance(table, CliTable):
            table.update_country(row, participant_id, country_code)
        else:
            table.update_item(
                Key={"session_id": row["session_id"]},
                UpdateExpression="SET collection_country_code = :country",
                ConditionExpression=(
                    Attr("participant_id").eq(participant_id)
                    & Attr("status").eq("received")
                    & Attr("s3_key").eq(row["s3_key"])
                    & Attr("uploaded_at_ms").eq(row["uploaded_at_ms"])
                    & (Attr("collection_country_code").not_exists()
                       | Attr("collection_country_code").eq(country_code))
                ),
                ExpressionAttributeValues={":country": country_code},
            )
        updated += 1
    return updated


def verify_manifest(table, manifest):
    if manifest.get("schema_version") != 1 or manifest.get("table") != table.name:
        raise ValueError("Manifest schema or table does not match")
    expected = manifest["collection_country_code"]
    for row in manifest["sessions"]:
        item = table.get_item(
            Key={"session_id": row["session_id"]}, ConsistentRead=True
        ).get("Item")
        if (item is None or item.get("participant_id") != manifest["participant_id"]
                or item.get("s3_key") != row["s3_key"]
                or item.get("collection_country_code") != expected):
            raise ValueError(f"Country verification failed for {row['session_id']}")
    return len(manifest["sessions"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--table", default="TransportSessions")
    parser.add_argument("--region", default="ap-southeast-2")
    commands = parser.add_subparsers(dest="command", required=True)
    inventory_parser = commands.add_parser("inventory")
    inventory_parser.add_argument("--bucket", required=True)
    inventory_parser.add_argument("--participant-id", required=True)
    inventory_parser.add_argument("--country-code", required=True)
    inventory_parser.add_argument("--output-dir", required=True, type=Path)
    inventory_parser.add_argument("--manifest", required=True, type=Path)
    apply_parser = commands.add_parser("apply")
    apply_parser.add_argument("--manifest", required=True, type=Path)
    verify_parser = commands.add_parser("verify")
    verify_parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    session = boto3.Session(region_name=args.region)
    if session.get_credentials() is None:
        table = CliTable(args.table, args.region)
        s3 = CliS3(table)
    else:
        table = session.resource("dynamodb").Table(args.table)
        s3 = session.client("s3")
    if args.command == "inventory":
        manifest = inventory(table, s3, args.bucket, args.participant_id,
                             args.country_code, args.output_dir)
        args.manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"Reviewed inventory written: {len(manifest['sessions'])} sessions")
    elif args.command == "apply":
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        print(f"Labelled {apply_manifest(table, s3, manifest)} reviewed sessions")
    else:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        print(f"Verified {verify_manifest(table, manifest)} country labels")


if __name__ == "__main__":
    main()
