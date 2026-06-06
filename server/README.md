# Transport Data Collector Server

AWS SAM backend for invite-only uploads from the Flutter data collector app.

## Endpoints

- `POST /sessions/request-upload`
  - Validates an invite code.
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
python scripts/create_invite_code.py --code KAIS-7F3Q-22 --participant-id participant_001
```

The script prints a DynamoDB item you can insert manually or with the AWS CLI.

## Upload Headers

The presigned S3 URL is signed for:

- `Content-Type: application/json`
- `Content-Encoding: gzip`

The Flutter client must send those exact headers when uploading.
