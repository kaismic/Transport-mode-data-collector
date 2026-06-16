import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/transport_modes.dart';
import '../models/sensor_manifest.dart';
import 'foreground_task_handler.dart';

@pragma('vm:entry-point')
void startRecordingCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

class RecordingService {
  RecordingService(this._db);

  final AppDatabase _db;

  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'transport_recording',
        channelName: 'Transport recording',
        channelDescription: 'Shows active transport data recording sessions.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        allowWakeLock: true,
      ),
    );
  }

  Future<String> startSession({
    required String deviceUuid,
    required String vehicleType,
  }) async {
    if (!allowedVehicleTypes.contains(vehicleType)) {
      throw ArgumentError.value(vehicleType, 'vehicleType', 'Unsupported type');
    }

    await Permission.notification.request();
    initForegroundTask();

    final sessionId = const Uuid().v4();
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _db.sessionDao.insertSession(
      SessionsCompanion.insert(
        id: sessionId,
        deviceUuid: deviceUuid,
        vehicleType: vehicleType,
        startedAtMs: startedAtMs,
        sensorManifest: SensorManifest.empty().toJson(),
      ),
    );

    await FlutterForegroundTask.saveData(key: 'session_id', value: sessionId);
    await FlutterForegroundTask.saveData(
      key: 'started_at_ms',
      value: startedAtMs,
    );

    final mode = transportModeFor(vehicleType);
    final result = await FlutterForegroundTask.startService(
      serviceId: 4101,
      notificationTitle: 'Recording ${mode.label}',
      notificationText: 'Elapsed 00:00',
      notificationButtons: [const NotificationButton(id: 'stop', text: 'Stop')],
      callback: startRecordingCallback,
    );
    if (result is ServiceRequestFailure) {
      await FlutterForegroundTask.removeData(key: 'session_id');
      await FlutterForegroundTask.removeData(key: 'started_at_ms');
      await _db.sessionDao.deleteSessionWithSamples(sessionId);
      throw Exception('Could not start foreground service: ${result.error}');
    }
    return sessionId;
  }

  Future<void> stopSession({required String sessionId}) async {
    final result = await stopForegroundService();
    final stillRunning = await isRecording;
    if (stillRunning) {
      final reason = result is ServiceRequestFailure
          ? result.error
          : 'service is still running';
      throw Exception('Could not stop foreground service: $reason');
    }

    // The task isolate has a separate Drift connection, so its write does not
    // invalidate streams owned by the UI connection. Avoid selecting the row
    // here because the task isolate can still be releasing its SQLite write
    // lock after stopService returns.
    await _retryDatabaseLock(
      () => _db.sessionDao.markStopObserved(
        id: sessionId,
        stoppedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await clearRecordingMetadata();
  }

  Future<ServiceRequestResult> stopForegroundService() {
    return FlutterForegroundTask.stopService();
  }

  Future<void> clearRecordingMetadata() async {
    await FlutterForegroundTask.removeData(key: 'session_id');
    await FlutterForegroundTask.removeData(key: 'started_at_ms');
  }

  Future<ActiveRecordingSession?> restoreActiveSession() async {
    if (!await isRecording) return null;

    final sessionId = await FlutterForegroundTask.getData<String>(
      key: 'session_id',
    );
    final startedAtMs = await FlutterForegroundTask.getData<int>(
      key: 'started_at_ms',
    );
    if (sessionId == null || startedAtMs == null) return null;

    final session = await _db.sessionDao.getSession(sessionId);
    if (session == null || session.stoppedAtMs != null) return null;

    return ActiveRecordingSession(
      sessionId: sessionId,
      vehicleType: session.vehicleType,
      startedAtMs: startedAtMs,
    );
  }

  Future<bool> get isRecording => FlutterForegroundTask.isRunningService;

  Future<T> _retryDatabaseLock<T>(Future<T> Function() action) async {
    Object? lastError;
    const maxRetries = 5;
    for (var i = 0; i < maxRetries; i++) {
      try {
        return await action();
      } catch (error) {
        if (!_isDatabaseLocked(error)) rethrow;
        lastError = error;
        await Future<void>.delayed(
          Duration(milliseconds: (50 * math.pow(2, i)).toInt()),
        );
      }
    }
    try {
      return await action();
    } catch (error) {
      if (_isDatabaseLocked(error) && lastError != null) throw lastError;
      rethrow;
    }
  }

  bool _isDatabaseLocked(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('database is locked') ||
        message.contains('sqliteexception(5)');
  }
}

class ActiveRecordingSession {
  const ActiveRecordingSession({
    required this.sessionId,
    required this.vehicleType,
    required this.startedAtMs,
  });

  final String sessionId;
  final String vehicleType;
  final int startedAtMs;
}
