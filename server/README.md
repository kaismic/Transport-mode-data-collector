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

## Deploy

```bash
cd server
sam build
sam deploy --guided
```

After deploy, pass the `ApiBaseUrl` output to Flutter:

```bash
flutter run --dart-define=API_BASE_URL=https://xxxx.execute-api.ap-southeast-2.amazonaws.com/Prod
```

## Invite Codes

Invite codes are not stored directly. The presign Lambda hashes the submitted code with SHA-256 and looks up that hash in the `TransportInviteCodes` table.

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
`uploaded_at_ms`. Re-running the command downloads only rows with a newer
`uploaded_at_ms`. Set `"decompress": true` to also write `.json` copies beside
the gzipped payloads, and set `"overwrite": true` to redownload payloads that
already exist locally.

The config also supports `"checkpoint-file"` and `"since-ms"` for checkpoint
control. To download and print one payload directly, use `"download-s3-key"`
instead of `"sync-new"`.

The sync downloads rows whose participant IDs use the `participant_###` format.
Rows for `test_###` IDs are ignored. The command prints aggregate counts and
only includes per-session details for failed downloads.
