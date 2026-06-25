import argparse
import gzip
import json
import shutil
import sys
from pathlib import Path, PurePosixPath

import boto3
from boto3.dynamodb.conditions import Attr
from botocore.exceptions import MissingDependencyException


def main():
    parser = argparse.ArgumentParser(description="List or download received sessions.")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--table", default="TransportSessions")
    parser.add_argument("--download-s3-key")
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
        help="Override the checkpoint timestamp for this sync run.",
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
        session = load_session(args.bucket, args.download_s3_key)
        print(json.dumps(session, indent=2))
        return

    if args.sync_new:
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
    items = list_received_sessions(ddb)
    print(json.dumps(items, indent=2, default=str))


def load_session(bucket, s3_key):
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
    last_uploaded_at_ms = (
        since_ms if since_ms is not None else checkpoint.get("last_uploaded_at_ms", 0)
    )

    ddb_table = boto3.resource("dynamodb").Table(table)
    total_s3_session_count = count_received_sessions(ddb_table)
    new_sessions = list_received_sessions(
        ddb_table,
        uploaded_after_ms=last_uploaded_at_ms,
    )
    new_sessions.sort(key=lambda item: int(item["uploaded_at_ms"]))

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

    if new_sessions and not failures:
        updated_checkpoint_ms = max(int(item["uploaded_at_ms"]) for item in new_sessions)
        write_checkpoint(
            checkpoint_file,
            {
                "last_uploaded_at_ms": updated_checkpoint_ms,
                "source_table": table,
                "source_bucket": bucket,
            },
        )

    return {
        "total_s3_session_count": total_s3_session_count,
        "total_downloaded_count": len(downloaded),
        "total_download_failure_count": len(failures),
        "failed_downloads": failures,
    }


def count_received_sessions(table):
    total = 0
    scan_kwargs = {
        "FilterExpression": Attr("status").eq("received"),
        "Select": "COUNT",
    }
    while True:
        response = table.scan(**scan_kwargs)
        total += response.get("Count", 0)
        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            return total
        scan_kwargs["ExclusiveStartKey"] = last_key


def list_received_sessions(table, uploaded_after_ms=None):
    filter_expression = Attr("status").eq("received")
    if uploaded_after_ms is not None:
        filter_expression = filter_expression & Attr("uploaded_at_ms").gt(
            uploaded_after_ms
        )

    items = []
    scan_kwargs = {"FilterExpression": filter_expression}
    while True:
        response = table.scan(**scan_kwargs)
        items.extend(response.get("Items", []))
        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            return items
        scan_kwargs["ExclusiveStartKey"] = last_key


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
    value = data.get("last_uploaded_at_ms", 0)
    if not isinstance(value, int) or value < 0:
        raise ValueError(f"Invalid checkpoint value in {path}")
    return data


def write_checkpoint(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_name(f"{path.name}.tmp")
    tmp_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    tmp_path.replace(path)


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
