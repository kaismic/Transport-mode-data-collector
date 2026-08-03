import argparse
from datetime import datetime

import boto3
from boto3.dynamodb.conditions import Attr


SYNC_PARTITION = "received"


def main():
    parser = argparse.ArgumentParser(
        description="Backfill ordered sync keys for existing received sessions."
    )
    parser.add_argument("--table", default="TransportSessions")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    table = boto3.resource("dynamodb").Table(args.table)
    result = backfill(table, dry_run=args.dry_run)
    print(
        f"examined={result['examined']} updated={result['updated']} "
        f"skipped={result['skipped']}"
    )


def backfill(table, dry_run=False):
    examined = 0
    updated = 0
    skipped = 0
    scan_kwargs = {
        "FilterExpression": Attr("status").eq("received")
        & Attr("sync_key").not_exists(),
        "ProjectionExpression": (
            "session_id, confirmed_at, updated_at, uploaded_at_ms"
        ),
    }
    while True:
        response = table.scan(**scan_kwargs)
        for item in response.get("Items", []):
            examined += 1
            confirmed_at_ms = confirmation_time_ms(item)
            if confirmed_at_ms is None:
                skipped += 1
                continue
            if not dry_run:
                update_sync_fields(table, item["session_id"], confirmed_at_ms)
            updated += 1
        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break
        scan_kwargs["ExclusiveStartKey"] = last_key
    return {"examined": examined, "updated": updated, "skipped": skipped}


def confirmation_time_ms(item):
    for key in ("confirmed_at", "updated_at"):
        value = item.get(key)
        if not value:
            continue
        try:
            return int(datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp() * 1000)
        except ValueError:
            pass
    value = item.get("uploaded_at_ms")
    try:
        return int(value) if value is not None else None
    except (TypeError, ValueError):
        return None


def update_sync_fields(table, session_id, confirmed_at_ms):
    table.update_item(
        Key={"session_id": session_id},
        UpdateExpression=(
            "SET confirmed_at_ms = :confirmed_at_ms, "
            "sync_partition = :sync_partition, sync_key = :sync_key"
        ),
        ConditionExpression=(
            "#status = :received AND attribute_not_exists(sync_key)"
        ),
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":confirmed_at_ms": confirmed_at_ms,
            ":sync_partition": SYNC_PARTITION,
            ":sync_key": f"{confirmed_at_ms:013d}#{session_id}",
            ":received": "received",
        },
    )


if __name__ == "__main__":
    main()
