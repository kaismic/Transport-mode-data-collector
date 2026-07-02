import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/database/app_database.dart';
import '../services/sensor_service.dart';
import 'recording_task_messages.dart';

class RecordingTaskHandler extends TaskHandler {
  AppDatabase? _db;
  SensorService? _sensorService;
  StreamSubscription? _sampleSubscription;
  final _buffer = <SamplesCompanion>[];
  Future<void> _pendingFlush = Future<void>.value();
  Future<void> _pendingManifestPersist = Future<void>.value();
  String? _sessionId;
  int? _startedAtMs;
  String? _lastPersistedManifestJson;
  var _reportedReady = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sessionId = await FlutterForegroundTask.getData<String>(key: 'session_id');
    _startedAtMs = await FlutterForegroundTask.getData<int>(
      key: 'started_at_ms',
    );
    final sessionId = _sessionId;
    if (sessionId == null) {
      await FlutterForegroundTask.stopService();
      return;
    }

    _db = AppDatabase();
    _sensorService = SensorService();
    _sampleSubscription = _sensorService!.sampleStream.listen((sample) {
      _buffer.add(
        SamplesCompanion.insert(
          sessionId: sessionId,
          timestampMs: sample.timestampMs,
          accelX: sample.accelX,
          accelY: sample.accelY,
          accelZ: sample.accelZ,
          gyroX: sample.gyroX,
          gyroY: sample.gyroY,
          gyroZ: sample.gyroZ,
          magX: Value(sample.magX),
          magY: Value(sample.magY),
          magZ: Value(sample.magZ),
          pressure: Value(sample.pressure),
        ),
      );
      if (!_reportedReady) {
        _reportedReady = true;
        FlutterForegroundTask.sendDataToMain(
          recordingReadyTaskMessage(sessionId),
        );
        _persistManifestInBackground();
        _flushInBackground();
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _flushInBackground();
    _persistManifestInBackground();
    if (!Platform.isAndroid) return;

    final startedAtMs = _startedAtMs;
    if (startedAtMs != null) {
      final elapsed = Duration(
        milliseconds: DateTime.now().millisecondsSinceEpoch - startedAtMs,
      );
      unawaited(
        FlutterForegroundTask.updateService(
          notificationText: 'Elapsed ${_formatElapsed(elapsed)}',
        ),
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sampleSubscription?.cancel();
    await _flush();
    await _pendingManifestPersist.catchError((Object _) {});
    final db = _db;
    final sessionId = _sessionId;
    final sensorService = _sensorService;
    if (db != null && sessionId != null) {
      final manifestJson =
          sensorService?.manifest.toJson() ?? SensorManifestFallback.json;
      await _retryDatabaseLock(
        () => db.sessionDao.markStopped(
          id: sessionId,
          stoppedAtMs: DateTime.now().millisecondsSinceEpoch,
          sensorManifest: manifestJson,
        ),
      );
      _lastPersistedManifestJson = manifestJson;
      await db.close();
    }
    await sensorService?.dispose();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'stop') {
      unawaited(FlutterForegroundTask.stopService());
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      unawaited(FlutterForegroundTask.stopService());
    }
  }

  void _flushInBackground() {
    unawaited(_flush().catchError((Object _) {}));
  }

  void _persistManifestInBackground() {
    unawaited(_persistManifest().catchError((Object _) {}));
  }

  Future<void> _flush() async {
    final flush = _pendingFlush
        .catchError((Object _) {})
        .then((_) => _drainBuffer());
    _pendingFlush = flush;
    return flush;
  }

  Future<void> _drainBuffer() async {
    final db = _db;
    if (db == null || _buffer.isEmpty) return;
    final rows = List<SamplesCompanion>.from(_buffer);
    await _retryDatabaseLock(() => db.sampleDao.insertSamples(rows));
    _buffer.removeRange(0, rows.length);
  }

  Future<void> _persistManifest() async {
    final persist = _pendingManifestPersist
        .catchError((Object _) {})
        .then((_) => _writeManifestIfChanged());
    _pendingManifestPersist = persist;
    return persist;
  }

  Future<void> _writeManifestIfChanged() async {
    final db = _db;
    final sessionId = _sessionId;
    final sensorService = _sensorService;
    if (db == null || sessionId == null || sensorService == null) return;

    final manifestJson = sensorService.manifest.toJson();
    if (manifestJson == _lastPersistedManifestJson) return;

    await _retryDatabaseLock(
      () => db.sessionDao.updateSensorManifest(
        id: sessionId,
        sensorManifest: manifestJson,
      ),
    );
    _lastPersistedManifestJson = manifestJson;
  }

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

  String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = elapsed.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class SensorManifestFallback {
  static const json =
      '{"accelerometer":{"available":false},"gyroscope":{"available":false},'
      '"magnetometer":{"available":false},"barometer":{"available":false}}';
}
