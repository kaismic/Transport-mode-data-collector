import argparse
import gzip
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import MissingDependencyException


PARTICIPANT_ID_PATTERN = re.compile(r"^participant_\d{3}$")
SYNC_CHECKPOINT_FILTER = PARTICIPANT_ID_PATTERN.pattern
SYNC_INDEX_NAME = "received-sync-index"
SYNC_PARTITION = "received"
SYNC_CHECKPOINT_VERSION = 2


def main():
    parser = argparse.ArgumentParser(description="List or download received sessions.")
    parser.add_argument("--bucket")
    parser.add_argument("--table", default="TransportSessions")
    parser.add_argument("--download-s3-key")
    parser.add_argument(
        "--participant-stats",
        action="store_true",
        help=(
            "List upload counts and latest upload details for participants with "
            "at least one received session."
        ),
    )
    parser.add_argument(
        "--sync-new",
        action="store_true",
        help="Download received sessions newer than the local checkpoint.",
    )
    parser.add_argument(
        "--output-dir",
        default="downloaded_sessions",
        help="Directory used by --sync-new.",
    )
    parser.add_argument(
        "--checkpoint-file",
        help=(
            "JSON checkpoint file used by --sync-new. Defaults to "
            "<output-dir>/.download_checkpoint.json."
        ),
    )
    parser.add_argument(
        "--since-ms",
        type=int,
        help="Override the checkpoint with a server confirmation timestamp.",
    )
    parser.add_argument(
        "--decompress",
        action="store_true",
        help="Also write a decompressed .json copy beside each .json.gz payload.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Redownload payloads even when the local file already exists.",
    )
    args = parser.parse_args()

    if args.download_s3_key:
        require_bucket(args.bucket)
        session = load_session(args.bucket, args.download_s3_key)
        print(json.dumps(session, indent=2))
        return

    if args.sync_new:
        require_bucket(args.bucket)
        output_dir = Path(args.output_dir)
        checkpoint_file = (
            Path(args.checkpoint_file)
            if args.checkpoint_file
            else output_dir / ".download_checkpoint.json"
        )
        summary = sync_new_sessions(
            bucket=args.bucket,
            table=args.table,
            output_dir=output_dir,
            checkpoint_file=checkpoint_file,
            since_ms=args.since_ms,
            decompress=args.decompress,
            overwrite=args.overwrite,
        )
        print(json.dumps(summary, indent=2, default=str))
        return

    ddb = boto3.resource("dynamodb").Table(args.table)
    if args.participant_stats:
        stats = list_participant_upload_stats(ddb)
        print(json.dumps(stats, indent=2, default=str))
        return

    items = list_received_sessions(ddb)
    print(json.dumps(items, indent=2, default=str))


def require_bucket(bucket):
    if not bucket:
        raise ValueError("--bucket is required for this operation")


def load_session(bucket, s3_key):
    if not is_allowed_sync_s3_key(s3_key):
        raise ValueError(f"S3 key is not for an allowed participant: {s3_key}")
    obj = boto3.client("s3").get_object(Bucket=bucket, Key=s3_key)
    raw = gzip.decompress(obj["Body"].read())
    return json.loads(raw)


def sync_new_sessions(
    bucket,
    table,
    output_dir,
    checkpoint_file,
    since_ms,
    decompress,
    overwrite,
):
    output_dir.mkdir(parents=True, exist_ok=True)
    checkpoint = read_checkpoint(checkpoint_file)
    last_sync_key = checkpoint_sync_key(
        checkpoint,
        since_ms,
        source_table=table,
        source_bucket=bucket,
    )

    ddb_table = boto3.resource("dynamodb").Table(table)
    discovered_sessions = query_received_sessions(
        ddb_table,
        after_sync_key=last_sync_key,
    )
    new_sessions = allowed_sync_sessions(discovered_sessions)

    s3 = boto3.client("s3")
    downloaded = []
    failures = []
    for item in new_sessions:
        try:
            result = download_session(
                s3=s3,
                bucket=bucket,
                item=item,
                output_dir=output_dir,
                decompress=decompress,
                overwrite=overwrite,
            )
            if result["downloaded"]:
                downloaded.append(result)
        except Exception as exc:
            failures.append(
                {
                    "session_id": item.get("session_id"),
                    "s3_key": item.get("s3_key"),
                    "error": str(exc),
                }
            )

    if discovered_sessions and not failures:
        updated_sync_key = discovered_sessions[-1]["sync_key"]
        write_checkpoint(
            checkpoint_file,
            {
                "version": SYNC_CHECKPOINT_VERSION,
                "last_sync_key": updated_sync_key,
                "source_table": table,
                "source_bucket": bucket,
                "participant_id_pattern": SYNC_CHECKPOINT_FILTER,
                "source_index": SYNC_INDEX_NAME,
            },
        )

    return {
        "total_discovered_count": len(new_sessions),
        "total_downloaded_count": len(downloaded),
        "total_download_failure_count": len(failures),
        "failed_downloads": failures,
    }


def count_received_sessions(table):
    return len(list_received_sessions(table))


def list_participant_upload_stats(table):
    sessions = list_received_sessions(table)
    participants = {}

    for item in sessions:
        participant_id = item["participant_id"]
        uploaded_at_ms = int(item["uploaded_at_ms"])
        participant = participants.setdefault(
            participant_id,
            {
                "participant_id": participant_id,
                "total_upload_count": 0,
                "last_session_id": None,
                "last_s3_key": None,
                "last_uploaded_at_ms": None,
                "last_uploaded_at": None,
            },
        )

        participant["total_upload_count"] += 1
        if (
            participant["last_uploaded_at_ms"] is None
            or uploaded_at_ms > participant["last_uploaded_at_ms"]
        ):
            participant["last_session_id"] = item.get("session_id")
            participant["last_s3_key"] = item.get("s3_key")
            participant["last_uploaded_at_ms"] = uploaded_at_ms
            participant["last_uploaded_at"] = uploaded_at_iso(uploaded_at_ms)

    return {
        "total_participant_count": len(participants),
        "participants": [
            participants[participant_id]
            for participant_id in sorted(participants)
        ],
    }


def uploaded_at_iso(uploaded_at_ms):
    return datetime.fromtimestamp(uploaded_at_ms / 1000, tz=timezone.utc).isoformat()


def list_received_sessions(table, after_sync_key=None):
    return allowed_sync_sessions(
        query_received_sessions(table, after_sync_key=after_sync_key)
    )


def query_received_sessions(table, after_sync_key=None):
    items = []
    key_condition = Key("sync_partition").eq(SYNC_PARTITION)
    if after_sync_key:
        key_condition = key_condition & Key("sync_key").gt(after_sync_key)
    query_kwargs = {
        "IndexName": SYNC_INDEX_NAME,
        "KeyConditionExpression": key_condition,
    }
    while True:
        response = table.query(**query_kwargs)
        items.extend(response.get("Items", []))
        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            return items
        query_kwargs["ExclusiveStartKey"] = last_key


def allowed_sync_sessions(items):
    return [item for item in items if is_allowed_sync_participant(item)]


def is_allowed_sync_participant(item):
    participant_id = item.get("participant_id")
    return (
        isinstance(participant_id, str)
        and bool(PARTICIPANT_ID_PATTERN.fullmatch(participant_id))
    )


def is_allowed_sync_s3_key(s3_key):
    parts = PurePosixPath(s3_key).parts
    if len(parts) < 2 or parts[0] != "raw":
        return False
    return is_allowed_sync_participant({"participant_id": parts[1]})


def download_session(s3, bucket, item, output_dir, decompress, overwrite):
    s3_key = item["s3_key"]
    payload_path = output_dir / safe_s3_key_path(s3_key)
    payload_path.parent.mkdir(parents=True, exist_ok=True)

    downloaded = False
    if overwrite or not payload_path.exists():
        tmp_path = payload_path.with_name(f"{payload_path.name}.tmp")
        try:
            s3.download_file(bucket, s3_key, str(tmp_path))
            tmp_path.replace(payload_path)
        finally:
            if tmp_path.exists():
                tmp_path.unlink()
        downloaded = True

    metadata_path = payload_path.with_suffix(f"{payload_path.suffix}.metadata.json")
    metadata_path.write_text(json.dumps(item, indent=2, default=str), encoding="utf-8")

    json_path = None
    if decompress:
        json_path = payload_path.with_suffix("")
        if overwrite or not json_path.exists():
            with gzip.open(payload_path, "rb") as source:
                with json_path.open("wb") as target:
                    shutil.copyfileobj(source, target)

    return {
        "session_id": item.get("session_id"),
        "uploaded_at_ms": int(item["uploaded_at_ms"]),
        "s3_key": s3_key,
        "payload_path": str(payload_path),
        "metadata_path": str(metadata_path),
        "json_path": str(json_path) if json_path else None,
        "downloaded": downloaded,
    }


def safe_s3_key_path(s3_key):
    key_path = PurePosixPath(s3_key)
    if key_path.is_absolute():
        raise ValueError(f"Unsafe S3 key path: {s3_key}")
    parts = key_path.parts
    if any(part in {"", ".", ".."} for part in parts):
        raise ValueError(f"Unsafe S3 key path: {s3_key}")
    return Path(*parts)


def read_checkpoint(path):
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if data.get("version") == SYNC_CHECKPOINT_VERSION:
        value = data.get("last_sync_key", "")
        if not isinstance(value, str):
            raise ValueError(f"Invalid checkpoint value in {path}")
    return data


def write_checkpoint(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_name(f"{path.name}.tmp")
    tmp_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    tmp_path.replace(path)


def checkpoint_sync_key(
    checkpoint,
    since_ms,
    source_table=None,
    source_bucket=None,
):
    if since_ms is not None:
        if since_ms < 0:
            raise ValueError("since-ms must not be negative")
        return f"{since_ms:013d}#"
    if checkpoint.get("version") != SYNC_CHECKPOINT_VERSION:
        return ""
    if checkpoint.get("participant_id_pattern") != SYNC_CHECKPOINT_FILTER:
        return ""
    if checkpoint.get("source_index") != SYNC_INDEX_NAME:
        return ""
    if source_table is not None and checkpoint.get("source_table") != source_table:
        return ""
    if source_bucket is not None and checkpoint.get("source_bucket") != source_bucket:
        return ""
    return checkpoint.get("last_sync_key", "")


def print_aws_dependency_error(exc):
    print("AWS credential setup needs an extra Python dependency.", file=sys.stderr)
    print("", file=sys.stderr)
    print(str(exc), file=sys.stderr)
    print("", file=sys.stderr)
    print(
        'Install it into this Python environment with: python -m pip install "botocore[crt]"',
        file=sys.stderr,
    )


if __name__ == "__main__":
    try:
        main()
    except MissingDependencyException as exc:
        print_aws_dependency_error(exc)
        sys.exit(2)
