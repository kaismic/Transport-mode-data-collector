import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/features/recording/bloc/recording_bloc.dart';
import 'package:transport_data_collector/features/recording/services/recording_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'restores active recording when the foreground service is running',
    () async {
      final startedAtMs = DateTime.now()
          .subtract(const Duration(seconds: 12))
          .millisecondsSinceEpoch;
      final service = _FakeRecordingService(
        database,
        activeSession: ActiveRecordingSession(
          sessionId: 'session-id',
          vehicleType: 'train',
          startedAtMs: startedAtMs,
        ),
      );
      final bloc = RecordingBloc(
        recordingService: service,
        deviceUuid: 'device-id',
      );

      final active = await bloc.stream
          .where((state) => state is RecordingActive)
          .cast<RecordingActive>()
          .first;

      expect(active.sessionId, 'session-id');
      expect(active.vehicleType, 'train');
      expect(active.elapsed.inSeconds, greaterThanOrEqualTo(12));
      await bloc.close();
    },
  );

  test('returns to idle when there is no active foreground service', () async {
    final bloc = RecordingBloc(
      recordingService: _FakeRecordingService(database),
      deviceUuid: 'device-id',
    );

    expect(
      await bloc.stream
          .where((state) => state is RecordingIdle)
          .cast<RecordingIdle>()
          .first,
      isA<RecordingIdle>(),
    );
    await bloc.close();
  });

  test(
    'waits for foreground service teardown before returning to idle',
    () async {
      final stopCompleter = Completer<void>();
      final service = _FakeRecordingService(
        database,
        activeSession: ActiveRecordingSession(
          sessionId: 'session-id',
          vehicleType: 'train',
          startedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
        stopCompleter: stopCompleter,
      );
      final bloc = RecordingBloc(
        recordingService: service,
        deviceUuid: 'device-id',
      );

      await bloc.stream
          .where((state) => state is RecordingActive)
          .cast<RecordingActive>()
          .first;
      bloc.add(const StopRecordingRequested());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<RecordingActive>());

      final idleState = bloc.stream
          .where((state) => state is RecordingIdle)
          .cast<RecordingIdle>()
          .first;
      stopCompleter.complete();
      expect(await idleState, isA<RecordingIdle>());
      expect(service.stoppedSessionId, 'session-id');
      await bloc.close();
    },
  );

  test(
    'finalizes active recording when the foreground service stops externally',
    () async {
      final service = _FakeRecordingService(
        database,
        activeSession: ActiveRecordingSession(
          sessionId: 'session-id',
          vehicleType: 'train',
          startedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      final bloc = RecordingBloc(
        recordingService: service,
        deviceUuid: 'device-id',
        tickInterval: const Duration(milliseconds: 10),
      );

      await bloc.stream
          .where((state) => state is RecordingActive)
          .cast<RecordingActive>()
          .first;
      service.serviceRunning = false;

      expect(
        await bloc.stream
            .where((state) => state is RecordingIdle)
            .cast<RecordingIdle>()
            .first,
        isA<RecordingIdle>(),
      );
      expect(service.stoppedSessionId, 'session-id');
      await bloc.close();
    },
  );

  test(
    'restore finalizes stale active state after external notification stop',
    () async {
      final service = _FakeRecordingService(
        database,
        activeSession: ActiveRecordingSession(
          sessionId: 'session-id',
          vehicleType: 'train',
          startedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      final bloc = RecordingBloc(
        recordingService: service,
        deviceUuid: 'device-id',
        tickInterval: const Duration(days: 1),
      );

      await bloc.stream
          .where((state) => state is RecordingActive)
          .cast<RecordingActive>()
          .first;
      service.serviceRunning = false;
      bloc.add(const RestoreRecordingRequested());

      expect(
        await bloc.stream
            .where((state) => state is RecordingIdle)
            .cast<RecordingIdle>()
            .first,
        isA<RecordingIdle>(),
      );
      expect(service.stoppedSessionId, 'session-id');
      await bloc.close();
    },
  );
}

class _FakeRecordingService extends RecordingService {
  _FakeRecordingService(
    super.database, {
    ActiveRecordingSession? activeSession,
    this.stopCompleter,
    bool? serviceRunning,
  }) : activeSession = activeSession,
       serviceRunning = serviceRunning ?? activeSession != null;

  final ActiveRecordingSession? activeSession;
  final Completer<void>? stopCompleter;
  bool serviceRunning;
  String? stoppedSessionId;

  @override
  Future<ActiveRecordingSession?> restoreActiveSession() async {
    return serviceRunning ? activeSession : null;
  }

  @override
  Future<void> stopSession({required String sessionId}) {
    stoppedSessionId = sessionId;
    final future = stopCompleter?.future ?? Future<void>.value();
    return future.whenComplete(() => serviceRunning = false);
  }

  @override
  Future<bool> get isRecording async => serviceRunning;
}
