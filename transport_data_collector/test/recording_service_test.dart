import 'package:drift/native.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/features/recording/services/recording_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'marks the session stopped after the foreground service stops',
    () async {
      await _insertActiveSession(database);
      final service = _FakeRecordingService(database);

      await service.stopSession(sessionId: 'session-id');

      final session = await database.sessionDao.getSession('session-id');
      expect(session?.stoppedAtMs, isNotNull);
      expect(session?.trimmedEndMs, session?.stoppedAtMs);
    },
  );

  test(
    'finalizes when the stop API races with an already stopped service',
    () async {
      await _insertActiveSession(database);
      final service = _FakeRecordingService(
        database,
        stopResult: ServiceRequestFailure(error: StateError('already stopped')),
      );

      await service.stopSession(sessionId: 'session-id');

      final session = await database.sessionDao.getSession('session-id');
      expect(session?.stoppedAtMs, isNotNull);
    },
  );

  test(
    'does not mark the session stopped while the service is running',
    () async {
      await _insertActiveSession(database);
      final service = _FakeRecordingService(database, stillRunning: true);

      await expectLater(
        service.stopSession(sessionId: 'session-id'),
        throwsA(isA<Exception>()),
      );

      final session = await database.sessionDao.getSession('session-id');
      expect(session?.stoppedAtMs, isNull);
    },
  );
}

Future<void> _insertActiveSession(AppDatabase database) {
  return database.sessionDao.insertSession(
    SessionsCompanion.insert(
      id: 'session-id',
      deviceUuid: 'device-id',
      vehicleType: 'car',
      startedAtMs: 1000,
      sensorManifest: '{}',
    ),
  );
}

class _FakeRecordingService extends RecordingService {
  _FakeRecordingService(
    super.database, {
    this.stillRunning = false,
    this.stopResult = const ServiceRequestSuccess(),
  });

  final bool stillRunning;
  final ServiceRequestResult stopResult;

  @override
  Future<ServiceRequestResult> stopForegroundService() async => stopResult;

  @override
  Future<void> clearRecordingMetadata() async {}

  @override
  Future<bool> get isRecording async => stillRunning;
}
