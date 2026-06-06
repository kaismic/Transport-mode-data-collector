import base64
import hashlib
import json
import os
import re
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Attr
from botocore.config import Config


s3 = boto3.client(
    "s3",
    region_name=os.environ["AWS_REGION"],
    config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
)
dynamodb = boto3.resource("dynamodb")
sessions_table = dynamodb.Table(os.environ["SESSIONS_TABLE_NAME"])
invite_codes_table = dynamodb.Table(os.environ["INVITE_CODES_TABLE_NAME"])

BUCKET_NAME = os.environ["BUCKET_NAME"]
ALLOWED_VEHICLE_TYPES = {"car", "bus", "train"}
UUID_RE = re.compile(r"^[0-9a-fA-F-]{32,36}$")
MAX_SAMPLE_COUNT = 2_000_000


def handler(event, context):
    try:
        body = _json_body(event)
        payload = _validate_body(body)
        invite = _lookup_invite(payload["invite_code"])
        if not invite:
            return _response(403, {"message": "Invalid or inactive invite code"})

        participant_id = invite["participant_id"]
        s3_key = (
            f"raw/{participant_id}/{payload['device_uuid']}/"
            f"{payload['session_id']}.json.gz"
        )
        presigned_url = s3.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": BUCKET_NAME,
                "Key": s3_key,
                "ContentType": "application/json",
                "ContentEncoding": "gzip",
            },
            ExpiresIn=900,
            HttpMethod="PUT",
        )

        now_iso = datetime.now(timezone.utc).isoformat()
        sessions_table.put_item(
            Item={
                "session_id": payload["session_id"],
                "participant_id": participant_id,
                "device_uuid": payload["device_uuid"],
                "vehicle_type": payload["vehicle_type"],
                "started_at_ms": payload["started_at_ms"],
                "stopped_at_ms": payload["stopped_at_ms"],
                "trimmed_start_ms": payload["trimmed_start_ms"],
                "trimmed_end_ms": payload["trimmed_end_ms"],
                "uploaded_at_ms": payload["uploaded_at_ms"],
                "sensor_manifest": payload["sensor_manifest"],
                "sample_count": payload["sample_count"],
                "s3_key": s3_key,
                "status": "pending",
                "created_at": now_iso,
                "updated_at": now_iso,
            },
            ConditionExpression=Attr("session_id").not_exists(),
        )

        return _response(
            200,
            {
                "presigned_url": presigned_url,
                "session_id": payload["session_id"],
                "s3_key": s3_key,
                "expires_in_seconds": 900,
            },
        )
    except ValidationError as exc:
        return _response(400, {"message": str(exc)})
    except sessions_table.meta.client.exceptions.ConditionalCheckFailedException:
        return _response(409, {"message": "Session already exists"})


def _json_body(event):
    raw_body = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")
    try:
        return json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValidationError("Request body must be valid JSON") from exc


def _validate_body(body):
    required = {
        "invite_code",
        "session_id",
        "device_uuid",
        "vehicle_type",
        "started_at_ms",
        "stopped_at_ms",
        "trimmed_start_ms",
        "trimmed_end_ms",
        "uploaded_at_ms",
        "sensor_manifest",
        "sample_count",
    }
    missing = sorted(required - body.keys())
    if missing:
        raise ValidationError(f"Missing required field(s): {', '.join(missing)}")

    session_id = _string(body, "session_id")
    device_uuid = _string(body, "device_uuid")
    vehicle_type = _string(body, "vehicle_type")
    invite_code = _string(body, "invite_code").strip().upper()
    if vehicle_type not in ALLOWED_VEHICLE_TYPES:
        raise ValidationError("vehicle_type must be one of: car, bus, train")
    if not UUID_RE.match(session_id):
        raise ValidationError("session_id must be a UUID-like string")
    if not UUID_RE.match(device_uuid):
        raise ValidationError("device_uuid must be a UUID-like string")

    started_at_ms = _integer(body, "started_at_ms")
    stopped_at_ms = _integer(body, "stopped_at_ms")
    trimmed_start_ms = _integer(body, "trimmed_start_ms")
    trimmed_end_ms = _integer(body, "trimmed_end_ms")
    uploaded_at_ms = _integer(body, "uploaded_at_ms")
    sample_count = _integer(body, "sample_count")
    if not started_at_ms <= trimmed_start_ms <= trimmed_end_ms <= stopped_at_ms:
        raise ValidationError("Trim timestamps must be inside the session duration")
    if uploaded_at_ms < stopped_at_ms:
        raise ValidationError("uploaded_at_ms must be after stopped_at_ms")
    if sample_count <= 0 or sample_count > MAX_SAMPLE_COUNT:
        raise ValidationError("sample_count is outside the allowed range")

    sensor_manifest = body["sensor_manifest"]
    if isinstance(sensor_manifest, str):
        try:
            sensor_manifest = json.loads(sensor_manifest)
        except json.JSONDecodeError as exc:
            raise ValidationError("sensor_manifest string must contain JSON") from exc
    if not isinstance(sensor_manifest, dict):
        raise ValidationError("sensor_manifest must be an object")

    return {
        "invite_code": invite_code,
        "session_id": session_id,
        "device_uuid": device_uuid,
        "vehicle_type": vehicle_type,
        "started_at_ms": started_at_ms,
        "stopped_at_ms": stopped_at_ms,
        "trimmed_start_ms": trimmed_start_ms,
        "trimmed_end_ms": trimmed_end_ms,
        "uploaded_at_ms": uploaded_at_ms,
        "sensor_manifest": sensor_manifest,
        "sample_count": sample_count,
    }


def _lookup_invite(invite_code):
    code_hash = hashlib.sha256(invite_code.encode("utf-8")).hexdigest()
    item = invite_codes_table.get_item(Key={"code_hash": code_hash}).get("Item")
    if not item or not item.get("active", False):
        return None
    return item


def _string(body, field):
    value = body[field]
    if not isinstance(value, str) or not value.strip():
        raise ValidationError(f"{field} must be a non-empty string")
    return value.strip()


def _integer(body, field):
    value = body[field]
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
