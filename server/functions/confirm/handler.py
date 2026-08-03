import base64
import json
import os
from datetime import datetime, timezone

import boto3


dynamodb = boto3.resource("dynamodb")
sessions_table = dynamodb.Table(os.environ["SESSIONS_TABLE_NAME"])


def handler(event, context):
    try:
        body = _json_body(event)
        session_id = _string(body, "session_id")
        uploaded_at_ms = _integer(body, "uploaded_at_ms")
    except ValidationError as exc:
        return _response(400, {"message": str(exc)})

    try:
        now = datetime.now(timezone.utc)
        now_iso = now.isoformat()
        confirmed_at_ms = int(now.timestamp() * 1000)
        sync_key = f"{confirmed_at_ms:013d}#{session_id}"
        result = sessions_table.update_item(
            Key={"session_id": session_id},
            UpdateExpression=(
                "SET #status = :received, "
                "confirmed_at = if_not_exists(confirmed_at, :confirmed_at), "
                "confirmed_at_ms = if_not_exists(confirmed_at_ms, :confirmed_at_ms), "
                "sync_partition = if_not_exists(sync_partition, :sync_partition), "
                "sync_key = if_not_exists(sync_key, :sync_key), "
                "updated_at = :updated_at"
            ),
            ConditionExpression=(
                "attribute_exists(session_id) AND uploaded_at_ms = :uploaded_at_ms"
            ),
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":received": "received",
                ":confirmed_at": now_iso,
                ":confirmed_at_ms": confirmed_at_ms,
                ":sync_partition": "received",
                ":sync_key": sync_key,
                ":updated_at": now_iso,
                ":uploaded_at_ms": uploaded_at_ms,
            },
            ReturnValues="ALL_NEW",
        )
    except sessions_table.meta.client.exceptions.ConditionalCheckFailedException:
        return _response(404, {"message": "Pending session was not found"})

    return _response(
        200,
        {
            "session_id": result["Attributes"]["session_id"],
            "status": result["Attributes"]["status"],
        },
    )


def _json_body(event):
    raw_body = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")
    try:
        return json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValidationError("Request body must be valid JSON") from exc


def _string(body, field):
    value = body.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ValidationError(f"{field} must be a non-empty string")
    return value.strip()


def _integer(body, field):
    value = body.get(field)
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValidationError(f"{field} must be an integer")
    return value


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


class ValidationError(Exception):
    pass
