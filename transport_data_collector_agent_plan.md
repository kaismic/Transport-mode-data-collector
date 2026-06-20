# AI Agent Execution Plan — Transport Mode Data Collector (Flutter)

## Codex Revision Notes

This plan has been revised from the original Claude-generated draft to match the current project decisions.

### Product Decisions

- The Flutter app lives in a nested `transport_data_collector/` folder.
- Android package/org is `com.kaismic`.
- Version 1 supports only these transport labels: `car`, `bus`, and `train`.
- Transport labels should be defined in one app-side configuration/constants location so more labels can be added later without touching storage/upload contracts.
- GPS/location collection is intentionally excluded for availability, battery, and privacy reasons.
- The app is invite-only for v1. Each participant gets a revocable invite code; the backend maps valid invite codes to pseudonymous participant IDs.
- Raw sensor uploads should be treated as sensitive research data. Use a practical default retention policy of 24 months for raw uploads, then delete or de-identify unless continued retention is explicitly needed.

### Implementation Corrections

- Add `confirmPending` to the local `Sessions` table from schema version 1.
- Add version metadata to the upload payload: `collection_version`, `app_version`, and `schema_version`.
- Compute accelerometer magnitude as `sqrt(ax² + ay² + az²)`, not the squared magnitude.
- Send `sensor_manifest` to the backend as a parsed JSON object/map, not as a raw JSON string.
- Add DAO support for deleting a session and its samples if `DeleteSession` remains in scope.
- Batch SQLite sample writes aggressively; avoid one write per sensor sample during normal recording.
- Add server-side validation for allowed vehicle types, timestamp sanity, sample count limits, UUID shape, and invite-code validity.
- The upload API uses a two-step app flow from the UI perspective, but the server performs invite-code validation before issuing a presigned URL.

### Server Decisions Already Implemented

- Server lives in `server/`.
- API endpoints:
  - `POST /sessions/request-upload`
  - direct `PUT` to returned S3 presigned URL
  - `POST /sessions/confirm-upload`
- S3 upload body is gzip-compressed JSON with exact headers:
  - `Content-Type: application/json`
  - `Content-Encoding: gzip`
- Invite codes are stored in DynamoDB as SHA-256 hashes, not raw codes.
- DynamoDB stores pseudonymous `participant_id` rather than participant names/emails.
- The presign endpoint accepts only `car`, `bus`, and `train`.

## Context

Build a Flutter mobile app (Android-first) that collects labelled sensor data from real transport journeys. Users select a vehicle type, record sensor data via a foreground service, trim recordings post-hoc, then upload to a server API. Data is used to train transport mode classification models.

This is a **sibling app** to an existing carbon emissions calculator. It is standalone, not integrated with that app.

---

## Constraints & Decisions

- **Platform**: Android-first. No iOS background execution support in v1.
- **Flutter version**: Latest stable. Use null-safety throughout.
- **State management**: `flutter_bloc` (consistent with the parent project's patterns).
- **Database**: `drift` (type-safe SQLite ORM). Do NOT use raw `sqflite`.
- **Sensor package**: `sensors_plus`. Do NOT use deprecated `sensors`.
- **Foreground service**: `flutter_foreground_task`. This handles both the service and notification.
- **HTTP**: `dio`.
- **Charts**: `fl_chart`.
- **Sampling target**: 50 Hz for IMU sensors, best-effort for barometer. Timestamp every sample with `DateTime.now().millisecondsSinceEpoch`.
- **Upload format**: JSON body (NDJSON-style samples array), gzip-compressed. Uploaded directly to S3 via presigned URL — NOT proxied through the API.
- **Upload flow**: Two-step presigned URL pattern (request URL → PUT to S3 → confirm). From the BLoC/UI perspective this is a single `UploadInProgress` state; the three-step sequence is encapsulated inside `UploadService`.
- **Server**: AWS Lambda + API Gateway + S3 + DynamoDB. `UploadService` should read the API base URL from a compile-time `String.fromEnvironment` constant so it can be injected at build time without hardcoding.
- **Authentication**: Invite-code gated uploads. The app sends an invite code to `/sessions/request-upload`; the backend validates its SHA-256 hash and stores/uploads under a pseudonymous `participant_id`.
- **Privacy**: No GPS/location, microphone, camera, contacts, or direct participant identifiers in the uploaded payload.
- **Retention**: Raw uploads default to 24-month retention for model development/debugging, then deletion or de-identification unless explicitly extended.

---

## Phase 1 — Project Scaffold

### 1.1 Create the Flutter project

```bash
flutter create transport_data_collector --org com.yourorg --platforms android
cd transport_data_collector
```

### 1.2 pubspec.yaml dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_bloc: ^8.1.5
  equatable: ^2.0.5
  drift: ^2.18.0
  drift_flutter: ^0.2.0          # provides DriftIsolate + flutter integration
  sensors_plus: ^6.0.0
  flutter_foreground_task: ^8.0.0
  shared_preferences: ^2.2.3
  uuid: ^4.4.0
  dio: ^5.4.3
  fl_chart: ^0.68.0
  intl: ^0.19.0

dev_dependencies:
  drift_dev: ^2.18.0
  build_runner: ^2.4.9
```

Run `flutter pub get`.

### 1.3 Android manifest additions

In `android/app/src/main/AndroidManifest.xml`, add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Inside `<application>`:

```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="specialUse"
    android:exported="false">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Research transport-mode recording using device motion sensors"/>
</service>
```

### 1.4 Directory structure

Create the following empty directories (add `.gitkeep` if needed):

```
lib/
  core/
    database/
      daos/
  features/
    recording/
      bloc/
      services/
      screens/
      widgets/
    review/
      bloc/
      screens/
      widgets/
    upload/
      bloc/
      services/
      models/
    home/
      screens/
```

---

## Phase 2 — Core: Device ID & Database

### 2.1 Device ID — `lib/core/device_id.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceId {
  static const _key = 'device_uuid';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }
}
```

### 2.2 Database schema — `lib/core/database/tables.dart`

```dart
import 'package:drift/drift.dart';

class Sessions extends Table {
  TextColumn get id => text()();                          // UUID
  TextColumn get deviceUuid => text()();
  TextColumn get vehicleType => text()();
  IntColumn get startedAtMs => integer()();
  IntColumn get stoppedAtMs => integer().nullable()();
  IntColumn get trimmedStartMs => integer().nullable()();
  IntColumn get trimmedEndMs => integer().nullable()();
  IntColumn get uploadedAtMs => integer().nullable()();
  TextColumn get sensorManifest => text()();              // JSON string
  BoolColumn get confirmPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Samples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  IntColumn get timestampMs => integer()();
  RealColumn get accelX => real()();
  RealColumn get accelY => real()();
  RealColumn get accelZ => real()();
  RealColumn get gyroX => real()();
  RealColumn get gyroY => real()();
  RealColumn get gyroZ => real()();
  RealColumn get magX => real().nullable()();
  RealColumn get magY => real().nullable()();
  RealColumn get magZ => real().nullable()();
  RealColumn get pressure => real().nullable()();
}
```

### 2.3 Database class — `lib/core/database/app_database.dart`

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';
import 'daos/session_dao.dart';
import 'daos/sample_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Sessions, Samples], daos: [SessionDao, SampleDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'transport_data.db'));

  @override
  int get schemaVersion => 1;
}
```

### 2.4 DAOs

**`lib/core/database/daos/session_dao.dart`**:

```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'session_dao.g.dart';

@DaoClass()
abstract class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  Future<void> insertSession(SessionsCompanion session) => into(db.sessions).insert(session);
  Future<void> updateSession(SessionsCompanion session) => db.sessions.insertOnConflictUpdate(session);
  Stream<List<Session>> watchAllSessions() => (select(db.sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAtMs)])).watch();
  Future<Session?> getSession(String id) => (select(db.sessions)..where((t) => t.id.equals(id))).getSingleOrNull();
}
```

**`lib/core/database/daos/sample_dao.dart`**:

```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'sample_dao.g.dart';

@DaoClass()
abstract class SampleDao extends DatabaseAccessor<AppDatabase> with _$SampleDaoMixin {
  SampleDao(super.db);

  Future<void> insertSample(SamplesCompanion sample) => into(db.samples).insert(sample);
  Future<void> insertSamples(List<SamplesCompanion> samples) =>
      batch((b) => b.insertAll(db.samples, samples));
  Future<List<Sample>> getSamplesForSession(String sessionId) =>
      (select(db.samples)..where((t) => t.sessionId.equals(sessionId))..orderBy([(t) => OrderingTerm.asc(t.timestampMs)])).get();
}
```

After creating these files, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Phase 3 — Sensor Service

### 3.1 Sensor manifest model — `lib/features/recording/models/sensor_manifest.dart`

```dart
import 'dart:convert';

class SensorInfo {
  final bool available;
  final double? observedHz;
  const SensorInfo({required this.available, this.observedHz});
  Map<String, dynamic> toJson() => {'available': available, if (observedHz != null) 'observed_hz': observedHz};
}

class SensorManifest {
  final SensorInfo accelerometer;
  final SensorInfo gyroscope;
  final SensorInfo magnetometer;
  final SensorInfo barometer;

  const SensorManifest({
    required this.accelerometer,
    required this.gyroscope,
    required this.magnetometer,
    required this.barometer,
  });

  String toJson() => jsonEncode({
    'accelerometer': accelerometer.toJson(),
    'gyroscope': gyroscope.toJson(),
    'magnetometer': magnetometer.toJson(),
    'barometer': barometer.toJson(),
  });
}
```

### 3.2 Sample model — `lib/features/recording/models/sensor_sample.dart`

```dart
import 'dart:math';

class SensorSample {
  final int timestampMs;
  final double accelX, accelY, accelZ;
  final double gyroX, gyroY, gyroZ;
  final double? magX, magY, magZ;
  final double? pressure;

  const SensorSample({
    required this.timestampMs,
    required this.accelX, required this.accelY, required this.accelZ,
    required this.gyroX, required this.gyroY, required this.gyroZ,
    this.magX, this.magY, this.magZ,
    this.pressure,
  });

  double get accelMagnitude {
    return sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
  }

  Map<String, dynamic> toJson() => {
    'ts': timestampMs,
    'ax': accelX, 'ay': accelY, 'az': accelZ,
    'gx': gyroX, 'gy': gyroY, 'gz': gyroZ,
    if (magX != null) 'mx': magX, if (magY != null) 'my': magY, if (magZ != null) 'mz': magZ,
    'p': pressure,
  };
}
```

### 3.3 Sensor service — `lib/features/recording/services/sensor_service.dart`

- Subscribe to `SensorsPlatform.instance.accelerometerEventStream(samplingPeriod: SensorInterval.fastest)`
- Same for gyroscope and magnetometer
- For barometer: use `sensors_plus` pressure stream if available; wrap in try/catch for `SensorNotAvailableException`
- Merge streams using `StreamZip` or maintain latest value per sensor and emit a combined `SensorSample` on each accelerometer tick
- Track event counts over a 2-second window to compute `observedHz`
- Expose: `Stream<SensorSample> get sampleStream`
- Expose: `SensorManifest get manifest` (computed after 2s warm-up)
- `void dispose()` cancels all subscriptions

**Implementation note**: Use the "latest value" merge pattern — keep `_latestGyro`, `_latestMag`, `_latestPressure` fields updated by their respective streams, and emit a `SensorSample` on every accelerometer event. This avoids `StreamZip` synchronisation issues with mismatched rates.

---

## Phase 4 — Recording Service & Foreground Task

### 4.1 Foreground task handler — `lib/features/recording/services/foreground_task_handler.dart`

Implement `TaskHandler` from `flutter_foreground_task`:

```dart
class RecordingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialise SensorService, open DB connection, start streaming
    // Read session ID from task data
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Flush buffered samples to DB in batches (e.g. every 1s)
    // Update notification elapsed time
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Flush remaining samples
    // Update session stoppedAtMs
    // Dispose SensorService
  }

  @override
  void onReceiveData(Object data) {
    // Handle 'stop' command sent from UI
    if (data == 'stop') FlutterForegroundTask.stopService();
  }
}
```

### 4.2 Recording service — `lib/features/recording/services/recording_service.dart`

```dart
class RecordingService {
  static Future<String> startSession({
    required String deviceUuid,
    required String vehicleType,
  }) async {
    // 1. Create session row in DB with new UUID, vehicleType, startedAtMs = now
    // 2. Configure FlutterForegroundTask notification:
    //    - Title: "Recording — $vehicleType"
    //    - Buttons: [NotificationButton(id: 'stop', text: 'Stop')]
    // 3. Start the foreground task, passing sessionId as task data
    // 4. Return sessionId
  }

  static Future<void> stopSession(String sessionId) async {
    // Send 'stop' data to foreground task
    await FlutterForegroundTask.sendDataToTask('stop');
    // Task handler updates stoppedAtMs on destroy
  }

  static bool get isRecording => FlutterForegroundTask.isRunningService;
}
```

---

## Phase 5 — Upload Service & Payload

### 5.1 Upload payload — `lib/features/upload/models/upload_payload.dart`

```dart
import 'dart:convert';
import 'package:transport_data_collector/core/database/tables.dart';
import 'package:transport_data_collector/features/recording/models/sensor_sample.dart';

class UploadPayload {
  final String deviceUuid;
  final String sessionId;
  final String vehicleType;
  final int startedAtMs;
  final int stoppedAtMs;
  final int trimmedStartMs;
  final int trimmedEndMs;
  final int uploadedAtMs;
  final int collectionVersion;
  final String appVersion;
  final int schemaVersion;
  final String sensorManifest;       // raw JSON string from DB
  final List<SensorSample> samples;  // already filtered to trim range

  const UploadPayload({
    required this.deviceUuid,
    required this.sessionId,
    required this.vehicleType,
    required this.startedAtMs,
    required this.stoppedAtMs,
    required this.trimmedStartMs,
    required this.trimmedEndMs,
    required this.uploadedAtMs,
    required this.sensorManifest,
    required this.samples,
    this.collectionVersion = 1,
    this.appVersion = 'unknown',
    this.schemaVersion = 1,
  });

  factory UploadPayload.fromSessionAndSamples({
    required Session session,
    required List<Sample> samples,
    required String deviceUuid,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final trimStart = session.trimmedStartMs ?? session.startedAtMs;
    final trimEnd   = session.trimmedEndMs   ?? session.stoppedAtMs!;

    final trimmedSamples = samples
        .where((s) => s.timestampMs >= trimStart && s.timestampMs <= trimEnd)
        .map((s) => SensorSample(
              timestampMs: s.timestampMs,
              accelX: s.accelX, accelY: s.accelY, accelZ: s.accelZ,
              gyroX:  s.gyroX,  gyroY:  s.gyroY,  gyroZ:  s.gyroZ,
              magX: s.magX, magY: s.magY, magZ: s.magZ,
              pressure: s.pressure,
            ))
        .toList();

    return UploadPayload(
      deviceUuid:    deviceUuid,
      sessionId:     session.id,
      vehicleType:   session.vehicleType,
      startedAtMs:   session.startedAtMs,
      stoppedAtMs:   session.stoppedAtMs!,
      trimmedStartMs: trimStart,
      trimmedEndMs:   trimEnd,
      uploadedAtMs:  now,
      sensorManifest: session.sensorManifest,
      samples:       trimmedSamples,
    );
  }

  Map<String, dynamic> toJson() => {
    'device_uuid':      deviceUuid,
    'session_id':       sessionId,
    'vehicle_type':     vehicleType,
    'started_at_ms':    startedAtMs,
    'stopped_at_ms':    stoppedAtMs,
    'trimmed_start_ms': trimmedStartMs,
    'trimmed_end_ms':   trimmedEndMs,
    'uploaded_at_ms':   uploadedAtMs,
    'collection_version': collectionVersion,
    'app_version': appVersion,
    'schema_version': schemaVersion,
    'sensor_manifest':  jsonDecode(sensorManifest),
    'samples':          samples.map((s) => s.toJson()).toList(),
  };

  /// Serialise to gzip-compressed bytes for the S3 PUT body.
  List<int> toGzipBytes() {
    final jsonBytes = utf8.encode(jsonEncode(toJson()));
    return GZipCodec().encode(jsonBytes);
  }
}
```

### 5.2 Upload exceptions — `lib/features/upload/models/upload_exception.dart`

```dart
sealed class UploadException implements Exception {
  const UploadException(this.message);
  final String message;
}

/// API returned an error when requesting the presigned URL.
class PresignRequestException extends UploadException {
  const PresignRequestException(super.message);
}

/// The S3 PUT failed (network error or non-2xx from S3).
class S3PutException extends UploadException {
  const S3PutException(super.message);
}

/// The confirm call to mark the session received failed.
class ConfirmException extends UploadException {
  const ConfirmException(super.message);
}
```

### 5.3 Upload service — `lib/features/upload/services/upload_service.dart`

The upload is a three-step sequence, fully encapsulated here. The BLoC sees a single `Future<void> uploadSession(...)` call.

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/upload_payload.dart';
import '../models/upload_exception.dart';

// Injected at build time:
//   flutter run --dart-define=API_BASE_URL=https://your-api.example.com
const String _kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://PLACEHOLDER.execute-api.ap-southeast-2.amazonaws.com/prod',
);

class UploadService {
  UploadService() {
    _api = Dio(BaseOptions(
      baseUrl: _kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    // S3 Dio instance — no base URL; presigned URLs are absolute.
    _s3 = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      // Large sessions may be several MB; allow enough time for the PUT.
      sendTimeout:    const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  late final Dio _api;
  late final Dio _s3;

  /// Full three-step upload. Throws a typed [UploadException] on any failure.
  Future<void> uploadSession(UploadPayload payload) async {
    // ── Step 1: Request a presigned S3 URL ───────────────────────────────
    final String presignedUrl;
    try {
      final resp = await _api.post<Map<String, dynamic>>(
        '/sessions/request-upload',
        data: {
          'session_id':   payload.sessionId,
          'device_uuid':  payload.deviceUuid,
          'vehicle_type': payload.vehicleType,
          'started_at_ms':    payload.startedAtMs,
          'stopped_at_ms':    payload.stoppedAtMs,
          'trimmed_start_ms': payload.trimmedStartMs,
          'trimmed_end_ms':   payload.trimmedEndMs,
          'uploaded_at_ms':   payload.uploadedAtMs,
          'sensor_manifest':  payload.sensorManifest,
          'sample_count':     payload.samples.length,
        },
      );
      presignedUrl = resp.data!['presigned_url'] as String;
    } on DioException catch (e) {
      throw PresignRequestException('Failed to get presigned URL: ${e.message}');
    }

    // ── Step 2: PUT payload bytes directly to S3 ─────────────────────────
    // S3 presigned PUTs require Content-Type and Content-Encoding to match
    // exactly what was signed. We sign for application/json + gzip.
    final gzipBytes = payload.toGzipBytes();
    try {
      await _s3.put<void>(
        presignedUrl,
        data: Stream.fromIterable([gzipBytes]),
        options: Options(
          headers: {
            HttpHeaders.contentTypeHeader:     'application/json',
            HttpHeaders.contentEncodingHeader: 'gzip',
            HttpHeaders.contentLengthHeader:   gzipBytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw S3PutException('S3 PUT failed: ${e.message}');
    }

    // ── Step 3: Confirm receipt ───────────────────────────────────────────
    try {
      await _api.post<void>(
        '/sessions/confirm-upload',
        data: {
          'session_id':    payload.sessionId,
          'uploaded_at_ms': payload.uploadedAtMs,
        },
      );
    } on DioException catch (e) {
      // S3 upload succeeded — data is safe. The confirm failure is recoverable:
      // the BLoC should surface a warning ("uploaded but not confirmed") rather
      // than a hard error, and retry confirm independently if desired.
      throw ConfirmException('Upload succeeded but confirm failed: ${e.message}');
    }
  }
}
```

**Note on `ConfirmException`**: because S3 already has the data at this point, the Upload BLoC should treat `ConfirmException` as a soft warning rather than a failure — mark the session with a `confirmPending` flag and retry on next app launch.
```

---

## Phase 6 — BLoC Layer

### 6.1 Recording BLoC — `lib/features/recording/bloc/`

**Events**: `StartRecordingRequested(vehicleType)`, `StopRecordingRequested()`
**States**: `RecordingIdle`, `RecordingActive(sessionId, vehicleType, startedAt, elapsedSeconds)`, `RecordingError(message)`

### 6.2 Review BLoC — `lib/features/review/bloc/`

**Events**: `LoadSessions()`, `TrimSession(sessionId, startMs, endMs)`, `DeleteSession(sessionId)`
**States**: `ReviewLoading`, `ReviewLoaded(sessions)`, `ReviewError`

### 6.3 Session Detail BLoC — `lib/features/review/bloc/`

**Events**: `LoadSessionDetail(sessionId)`, `UpdateTrim(startMs, endMs)`, `ConfirmTrim()`
**States**: `DetailLoading`, `DetailLoaded(session, samples, magnitudePoints)`, `DetailError`

Magnitude points for the chart: compute `sqrt(ax²+ay²+az²)` for each sample and downsample to max 500 points for rendering (LTTB algorithm or simple stride).

### 6.4 Upload BLoC — `lib/features/upload/bloc/`

**Events**: `UploadSession(sessionId)`
**States**: `UploadIdle`, `UploadInProgress`, `UploadSuccess`, `UploadFailure(error)`, `UploadConfirmPending(sessionId)` (S3 succeeded, confirm call failed — data is safe, retry later)

On `UploadSuccess` and `UploadConfirmPending`: write `uploadedAtMs` to the local session row. On `UploadConfirmPending`, also set a `confirmPending = true` flag (add a boolean column to the `Sessions` table) and retry the confirm-only call on the next app launch.

---

## Phase 7 — UI Screens

### 7.1 Home Screen — `lib/features/home/screens/home_screen.dart`

- Show device UUID (truncated, for debugging)
- Session summary: X recorded, Y pending upload, Z uploaded
- Two CTA buttons: **Start Recording** | **Review & Upload**
- Check `RecordingService.isRecording` on resume — if true, show "Recording in progress" banner with a **Stop** button

### 7.2 Vehicle Select Bottom Sheet

- `showModalBottomSheet` triggered from Home
- Grid of transport type chips: Car, Bus, Train
- On tap: dispatch `StartRecordingRequested(vehicleType)` and pop

### 7.3 Active Recording Screen

- Live elapsed timer (update every second via `Stream.periodic`)
- Sensor health chips: green = firing, amber = degraded rate, red = unavailable
- **Stop Recording** button → `StopRecordingRequested()`
- On stop: navigate to Home

### 7.4 Review List Screen

- `StreamBuilder` on `SessionDao.watchAllSessions()`
- `ListView` grouped by date
- Each tile: vehicle type icon, date/time, duration, trim indicator (if adjusted), upload status chip
- Tap → Session Review Screen
- FAB or app bar action: "Upload all pending"

### 7.5 Session Review Screen

- Two-panel layout: chart on top, controls below
- **Magnitude chart** (`fl_chart` `LineChart`): x-axis = elapsed seconds, y-axis = accel magnitude
  - Two draggable vertical lines for trim start and trim end
- **Trim controls** (below chart):
  - Dual `RangeSlider` (Flutter built-in) showing trim start / end
  - Toggle to switch to direct time input (`TextFormField` with HH:mm:ss validation)
- **Stats panel**: vehicle type, original duration, trimmed duration, sample count, sensors present
- **Confirm & Upload** button (primary) | **Delete** (destructive, with confirmation dialog)

---

## Phase 8 — Permission Handling

Request at runtime before starting first recording:

- `android.permission.POST_NOTIFICATIONS` (Android 13+)

Use `permission_handler` package:

```yaml
permission_handler: ^11.3.1
```

Add to manifest: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`

No special sensor permissions needed on Android for accelerometer/gyroscope/magnetometer/barometer — these are not gated by `dangerous` permissions.

---

## Phase 9 — Database Migration & Build

After any schema change:

```bash
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/schema_v1.json
dart run build_runner build --delete-conflicting-outputs
```

---

## Phase 10 — Server (AWS)

### Architecture

```
Flutter app
  │
  ├─ POST /sessions/request-upload  ──► API Gateway ──► Lambda: presign_handler
  │                                                          │
  │                                                          └─ creates DynamoDB record (status=pending)
  │                                                          └─ returns presigned S3 PUT URL (15 min TTL)
  │
  ├─ PUT {presigned_url}  ─────────────────────────────────► S3 (direct, bypasses API Gateway)
  │
  └─ POST /sessions/confirm-upload  ──► API Gateway ──► Lambda: confirm_handler
                                                             │
                                                             └─ updates DynamoDB record (status=received)
```

### S3 Bucket

```
Bucket name: transport-data-sessions-{account_id}
Key pattern: raw/{device_uuid}/{session_id}.json.gz
Lifecycle:   no expiry (retain indefinitely for ML use)
Versioning:  disabled (sessions are write-once)
Public access: BLOCKED
```

The presigned URL is signed for:
- Method: `PUT`
- Content-Type: `application/json`
- Content-Encoding: `gzip`
- Expiry: 900 seconds (15 minutes)

### DynamoDB Table

```
Table name:   TransportSessions
Partition key: session_id (String)
Sort key:      none

Attributes:
  session_id        String   (UUID)
  device_uuid       String
  vehicle_type      String
  started_at_ms     Number
  stopped_at_ms     Number
  trimmed_start_ms  Number
  trimmed_end_ms    Number
  uploaded_at_ms    Number
  sensor_manifest   Map      (parsed from JSON)
  sample_count      Number
  s3_key            String   (e.g. raw/{device_uuid}/{session_id}.json.gz)
  status            String   (pending | received)
  created_at        String   (ISO8601, for TTL / sorting)

GSI:  device_uuid-index  (PK: device_uuid, SK: uploaded_at_ms)
      — allows querying all sessions from a given device
```

### Lambda: `presign_handler`

**Trigger**: `POST /sessions/request-upload`

```python
import boto3, json, os, uuid
from datetime import datetime, timezone

s3  = boto3.client('s3')
ddb = boto3.resource('dynamodb').Table(os.environ['TABLE_NAME'])
BUCKET = os.environ['BUCKET_NAME']

def handler(event, context):
    body = json.loads(event['body'])
    session_id  = body['session_id']
    device_uuid = body['device_uuid']

    s3_key = f"raw/{device_uuid}/{session_id}.json.gz"

    # Generate presigned PUT URL — must match Content-Type + Content-Encoding
    # the client will send exactly.
    presigned_url = s3.generate_presigned_url(
        ClientMethod='put_object',
        Params={
            'Bucket': BUCKET,
            'Key': s3_key,
            'ContentType': 'application/json',
            'ContentEncoding': 'gzip',
        },
        ExpiresIn=900,
        HttpMethod='PUT',
    )

    # Write metadata to DynamoDB (status=pending until confirm)
    ddb.put_item(Item={
        'session_id':       session_id,
        'device_uuid':      device_uuid,
        'vehicle_type':     body['vehicle_type'],
        'started_at_ms':    body['started_at_ms'],
        'stopped_at_ms':    body['stopped_at_ms'],
        'trimmed_start_ms': body['trimmed_start_ms'],
        'trimmed_end_ms':   body['trimmed_end_ms'],
        'uploaded_at_ms':   body['uploaded_at_ms'],
        'sensor_manifest':  body['sensor_manifest'],  # already a dict
        'sample_count':     body['sample_count'],
        's3_key':           s3_key,
        'status':           'pending',
        'created_at':       datetime.now(timezone.utc).isoformat(),
    })

    return {
        'statusCode': 200,
        'body': json.dumps({'presigned_url': presigned_url, 'session_id': session_id}),
    }
```

### Lambda: `confirm_handler`

**Trigger**: `POST /sessions/confirm-upload`

```python
import boto3, json, os
from datetime import datetime, timezone

ddb = boto3.resource('dynamodb').Table(os.environ['TABLE_NAME'])

def handler(event, context):
    body = json.loads(event['body'])
    session_id    = body['session_id']
    uploaded_at_ms = body['uploaded_at_ms']

    ddb.update_item(
        Key={'session_id': session_id},
        UpdateExpression='SET #s = :received, confirmed_at = :ts',
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={
            ':received': 'received',
            ':ts': datetime.now(timezone.utc).isoformat(),
        },
    )

    return {
        'statusCode': 200,
        'body': json.dumps({'session_id': session_id, 'status': 'received'}),
    }
```

### Lambda IAM permissions

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GeneratePresignedUrl"
  ],
  "Resource": "arn:aws:s3:::transport-data-sessions-*/*"
},
{
  "Effect": "Allow",
  "Action": [
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:GetItem",
    "dynamodb:Query"
  ],
  "Resource": [
    "arn:aws:dynamodb:*:*:table/TransportSessions",
    "arn:aws:dynamodb:*:*:table/TransportSessions/index/*"
  ]
}
```

### SAM Template skeleton — `server/template.yaml`

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Runtime: python3.12
    Timeout: 10
    Environment:
      Variables:
        TABLE_NAME: !Ref SessionsTable
        BUCKET_NAME: !Ref SessionsBucket

Resources:

  SessionsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "transport-data-sessions-${AWS::AccountId}"
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      CorsConfiguration:
        CorsRules:
          - AllowedOrigins: ['*']
            AllowedMethods: [PUT]
            AllowedHeaders: ['Content-Type', 'Content-Encoding']
            MaxAge: 3600

  SessionsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: TransportSessions
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: session_id
          AttributeType: S
        - AttributeName: device_uuid
          AttributeType: S
        - AttributeName: uploaded_at_ms
          AttributeType: N
      KeySchema:
        - AttributeName: session_id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: device_uuid-index
          KeySchema:
            - AttributeName: device_uuid
              KeyType: HASH
            - AttributeName: uploaded_at_ms
              KeyType: RANGE
          Projection:
            ProjectionType: ALL

  PresignFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: functions/presign/
      Handler: handler.handler
      Policies:
        - S3WritePolicy:
            BucketName: !Ref SessionsBucket
        - DynamoDBCrudPolicy:
            TableName: !Ref SessionsTable
      Events:
        Api:
          Type: Api
          Properties:
            Path: /sessions/request-upload
            Method: post

  ConfirmFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: functions/confirm/
      Handler: handler.handler
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref SessionsTable
      Events:
        Api:
          Type: Api
          Properties:
            Path: /sessions/confirm-upload
            Method: post

Outputs:
  ApiBaseUrl:
    Value: !Sub "https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod"
    Description: "Pass this as API_BASE_URL to flutter build"
```

### Server directory structure

```
server/
  template.yaml
  functions/
    presign/
      handler.py
      requirements.txt    # boto3 only (included in Lambda runtime, list for clarity)
    confirm/
      handler.py
      requirements.txt
  scripts/
    deploy.sh             # sam build && sam deploy --guided
    query_sessions.py     # boto3 script: list/download sessions from DynamoDB + S3
```

### Deploy commands

```bash
cd server
sam build
sam deploy --guided   # first time — saves config to samconfig.toml
# Subsequent deploys:
sam build && sam deploy
```

After deploy, copy the `ApiBaseUrl` output value and pass it to Flutter builds:

```bash
flutter build apk --dart-define=API_BASE_URL=https://xxxx.execute-api.ap-southeast-2.amazonaws.com/Prod
flutter run          --dart-define=API_BASE_URL=https://xxxx.execute-api.ap-southeast-2.amazonaws.com/Prod
```

### Accessing datasets (Python pipeline)

```python
import boto3, json, gzip

s3  = boto3.client('s3')
ddb = boto3.resource('dynamodb').Table('TransportSessions')

# List all received sessions
resp = ddb.scan(FilterExpression=boto3.dynamodb.conditions.Attr('status').eq('received'))
sessions = resp['Items']

# Download and decompress a session
def load_session(s3_key: str) -> dict:
    obj = s3.get_object(Bucket='transport-data-sessions-{account_id}', Key=s3_key)
    raw = gzip.decompress(obj['Body'].read())
    return json.loads(raw)
```

---

## Key Invariants

1. `stoppedAtMs` must always be set before a session can be uploaded. Assert this in `UploadService`.
2. `trimmedStartMs` defaults to `startedAtMs`, `trimmedEndMs` defaults to `stoppedAtMs` if not explicitly set.
3. All timestamps are Unix epoch milliseconds. No `DateTime` strings in the DB or payload samples array.
4. `sensorManifest` is serialised to a JSON string for DB storage; deserialise before use.
5. The foreground task and the UI BLoC must not both write to the DB concurrently for the same session. The task owns writes during recording; the BLoC owns writes for trim/upload metadata.
6. Never delete samples from the DB after upload — retain for potential re-upload or local export.
7. The presigned URL is signed for exactly `Content-Type: application/json` + `Content-Encoding: gzip`. The Flutter client and the Lambda presigner must agree on these headers — any mismatch causes a 403 from S3.
8. A `ConfirmException` means the data reached S3 successfully. Do not surface this as a hard failure; set `confirmPending = true` in the local DB and retry the confirm-only call on next app launch.
9. The API base URL is injected via `--dart-define=API_BASE_URL=...` at build time, not hardcoded. The `defaultValue` placeholder in `String.fromEnvironment` is for local dev only and must never reach production.

---

## Checklist: Done When…

**Flutter app**
- [x] App generates and persists UUID on first launch
- [x] Selecting a vehicle type and pressing start creates a session and starts the foreground service
- [x] Sensor data is written to SQLite at ~50 Hz while the app is backgrounded
- [x] Persistent notification shows vehicle type and elapsed time with a working Stop button
- [x] Stopping the recording (notification or in-app) sets `stoppedAtMs` correctly
- [x] Review list shows all sessions with correct status badges
- [x] Session detail shows magnitude chart and trim sliders
- [x] Trim adjustments persist to `trimmedStartMs`/`trimmedEndMs` in the DB
- [x] Upload serialises only samples within the trim range and gzip-compresses the body
- [x] `UploadService` completes the full three-step flow (presign → PUT → confirm)
- [x] `ConfirmException` is treated as a soft warning; `confirmPending` flag is set and retried on next launch
- [x] Upload marks session with `uploadedAtMs` on success
- [x] Hard upload failures show an error and allow retry
- [x] App handles missing barometer gracefully (no crash, manifest shows `available: false`)
- [x] API base URL is configurable via `--dart-define` with no hardcoded production URL

**Server**
- [x] SAM template deploys cleanly with `sam build && sam deploy`
- [x] `presign_handler` returns a valid presigned URL and writes a `pending` DynamoDB record
- [x] A direct `curl` PUT to the presigned URL with `Content-Type: application/json` + `Content-Encoding: gzip` succeeds (HTTP 200 from S3)
- [x] `confirm_handler` updates the DynamoDB record status to `received`
- [x] A session uploaded from the Flutter app appears in DynamoDB with `status=received`
- [x] `query_sessions.py` can list and decompress sessions from S3 into a Python dict
