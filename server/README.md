# Transport Data Collector Server

AWS SAM backend for invite-only uploads from the Flutter data collector app.

## Endpoints

- `POST /sessions/request-upload`
  - Validates an invite code.
  - Validates the phone position (`hand`, `pocket`, `bag`, `stationary`, or
    `other`).
  - Writes a pending session metadata row to DynamoDB.
  - Returns a presigned S3 `PUT` URL.
- `POST /sessions/confirm-upload`
  - Marks a pending session as received after the app successfully uploads to S3.
  - Adds a server-generated confirmation timestamp and collision-safe ordered
    synchronization key.

## Deploy

```bash
cd server
sam build
sam deploy --guided
```

The deployment adds the `received-sync-index` global secondary index. After the
first deployment of this version, backfill existing received rows once:

```bash
python scripts/backfill_session_sync_keys.py --table TransportSessions --dry-run
python scripts/backfill_session_sync_keys.py --table TransportSessions
```

Run the dry run first and confirm the examined/updated counts. The backfill uses
`confirmed_at`, then `updated_at`, then `uploaded_at_ms` as its timestamp source.
It is idempotent because rows that already have `sync_key` are excluded.

After deploy, pass the `ApiBaseUrl` output to Flutter:

```bash
flutter run --dart-define=API_BASE_URL=https://xxxx.execute-api.ap-southeast-2.amazonaws.com/Prod
```

## Invite Codes

Invite codes are not stored directly. The presign Lambda hashes the submitted code with SHA-256 and looks up that hash in the `TransportInviteCodes` table.

The lookup uses a strongly consistent read so newly created or activated codes
are immediately usable and revoked codes are rejected. Invalid/inactive codes
return HTTP 403 with `code: INVALID_INVITE_CODE` and a readable `message`.
Deploy the updated presign Lambda for this behavior to take effect.

Run the presign regression tests with:

```bash
python -m unittest discover -s functions/presign -p "test_*.py"
```

Create a code with:

```bash
python scripts/create_invite_code.py --code EXAMPLE-INVITE-CODE --participant-id participant_001
```

The script prints a DynamoDB item you can insert manually or with the AWS CLI.

## Upload Headers

The presigned S3 URL is signed for:

- `Content-Type: application/json`
- `Content-Encoding: gzip`

The Flutter client must send those exact headers when uploading.

## Download Uploaded Sessions

Use `scripts/download_sessions.py` to sync newly received sessions from
DynamoDB/S3 using a JSON config file. By default, the script reads
`scripts/session-download.json`:

```bash
python scripts/download_sessions.py
```

Example `scripts/session-download.json`:

```json
{
  "bucket": "transport-data-sessions-123456789012",
  "table": "TransportSessions",
  "sync-new": true,
  "output-dir": "data/sessions"
}
```

You can pass another config path if needed:

```bash
python scripts/download_sessions.py scripts/session-download.json
```

If your AWS profile uses the AWS login credential provider, install boto3's
optional CRT dependency first:

```bash
python -m pip install "botocore[crt]"
```

The sync writes each uploaded `raw/.../*.json.gz` payload under the output
directory, writes a sibling `.metadata.json` file from the DynamoDB row, and
stores a `.download_checkpoint.json` file containing the latest downloaded
server confirmation cursor. Re-running the command queries
`received-sync-index` for later rows instead of scanning the table. Set
`"decompress": true` to also write `.json` copies beside the gzipped payloads,
and set `"overwrite": true` to redownload payloads that already exist locally.

The config also supports `"checkpoint-file"` and `"since-ms"` for checkpoint
control. `since-ms` now refers to the server confirmation timestamp. Legacy
`uploaded_at_ms` checkpoints are deliberately ignored once so the ordered index
can be synchronized completely. To download and print one payload directly,
use `"download-s3-key"` instead of `"sync-new"`.

The sync downloads rows whose participant IDs use the `participant_###` format.
Rows for `test_###` IDs are ignored. The command prints aggregate counts and
only includes per-session details for failed downloads.

To inspect upload coverage without downloading payloads, list participant
upload stats from DynamoDB:

```bash
python scripts/query_sessions.py --table TransportSessions --participant-stats
```

The stats output includes the total number of `participant_###` participants
with at least one received session, each participant's upload count, and their
latest session ID, S3 key, `uploaded_at_ms`, and UTC upload timestamp.
