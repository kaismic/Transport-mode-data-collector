import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/features/recording/services/recording_service.dart';
import 'package:transport_data_collector/features/recording/services/recording_task_messages.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('start rejects unsupported phone positions', () async {
    final service = _FakeRecordingService(database);

    await expectLater(
      service.startSession(
        deviceUuid: 'device-id',
        vehicleType: 'car',
        phonePosition: 'dashboard',
      ),
      throwsArgumentError,
    );

    expect(await database.sessionDao.getAllSessions(), isEmpty);
  });

  test('start waits until the foreground task reports a sample', () async {
    final service = _FakeRecordingService(database);

    final startFuture = service.startSession(
      deviceUuid: 'device-id',
      vehicleType: 'car',
      phonePosition: 'pocket',
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.startedForegroundService, isTrue);
    expect(await _isCompleted(startFuture), isFalse);

    final session = (await database.sessionDao.getAllSessions()).single;
    expect(session.phonePosition, 'pocket');
    service.reportReady(session.id);

    expect(await startFuture, session.id);
    expect(service.removedTaskDataCallback, isTrue);
  });

  test('start cleans up the session when no samples arrive', () async {
    final service = _FakeRecordingService(
      database,
      recordingReadyTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      service.startSession(
        deviceUuid: 'device-id',
        vehicleType: 'car',
        phonePosition: 'hand',
      ),
      throwsA(
        predicate(
          (Object error) => error.toString().contains(
            'Could not start recording: no sensor samples received',
          ),
        ),
      ),
    );

    expect(service.stoppedForegroundService, isTrue);
    expect(service.clearedRecordingMetadata, isTrue);
    expect(await database.sessionDao.getAllSessions(), isEmpty);
    expect(service.removedTaskDataCallback, isTrue);
  });

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
    'stop fallback preserves manifest for foreground finalization',
    () async {
      await _insertActiveSession(database);
      final service = _FakeRecordingService(database);

      await service.stopSession(sessionId: 'session-id');
      await database.sessionDao.markStopped(
        id: 'session-id',
        stoppedAtMs: 2000,
        sensorManifest: '{"accelerometer":{"available":true}}',
      );

      final session = await database.sessionDao.getSession('session-id');
      expect(session?.sensorManifest, '{"accelerometer":{"available":true}}');
      expect(session?.trimmedEndMs, isNotNull);
    },
  );

  test('stop fallback does not overwrite an already stopped session', () async {
    await _insertActiveSession(database);
    await database.sessionDao.markStopped(
      id: 'session-id',
      stoppedAtMs: 1500,
      sensorManifest: '{"existing":true}',
    );
    final service = _FakeRecordingService(database);

    await service.stopSession(sessionId: 'session-id');

    final session = await database.sessionDao.getSession('session-id');
    expect(session?.stoppedAtMs, 1500);
    expect(session?.trimmedEndMs, 1500);
    expect(session?.sensorManifest, '{"existing":true}');
  });

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

Future<bool> _isCompleted<T>(Future<T> future) async {
  var completed = false;
  unawaited(
    future.then((_) => completed = true, onError: (_) => completed = true),
  );
  await Future<void>.delayed(Duration.zero);
  return completed;
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
    this.database, {
    this.stillRunning = false,
    this.stopResult = const ServiceRequestSuccess(),
    Duration recordingReadyTimeout = const Duration(seconds: 10),
  }) : super(database, recordingReadyTimeout: recordingReadyTimeout);

  final AppDatabase database;
  final bool stillRunning;
  final ServiceRequestResult stopResult;
  void Function(Object data)? _taskDataCallback;
  var startedForegroundService = false;
  var stoppedForegroundService = false;
  var clearedRecordingMetadata = false;
  var removedTaskDataCallback = false;

  void reportReady(String sessionId) {
    _taskDataCallback?.call(recordingReadyTaskMessage(sessionId));
  }

  @override
  Future<ServiceRequestResult> startForegroundService({
    required String notificationTitle,
    required String notificationText,
    required List<NotificationButton> notificationButtons,
  }) async {
    startedForegroundService = true;
    return const ServiceRequestSuccess();
  }

  @override
  Future<ServiceRequestResult> stopForegroundService() async {
    stoppedForegroundService = true;
    return stopResult;
  }

  @override
  Future<void> requestNotificationPermission() async {}

  @override
  void initializeForegroundTask() {}

  @override
  Future<void> saveRecordingMetadata({
    required String sessionId,
    required int startedAtMs,
  }) async {}

  @override
  Future<void> clearRecordingMetadata() async {
    clearedRecordingMetadata = true;
  }

  @override
  void addTaskDataCallback(void Function(Object data) callback) {
    _taskDataCallback = callback;
  }

  @override
  void removeTaskDataCallback(void Function(Object data) callback) {
    if (_taskDataCallback == callback) {
      _taskDataCallback = null;
    }
    removedTaskDataCallback = true;
  }

  @override
  Future<bool> get isRecording async => stillRunning;
}
