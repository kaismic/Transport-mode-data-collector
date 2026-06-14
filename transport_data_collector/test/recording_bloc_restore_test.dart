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
}

class _FakeRecordingService extends RecordingService {
  _FakeRecordingService(
    super.database, {
    this.activeSession,
    this.stopCompleter,
  });

  final ActiveRecordingSession? activeSession;
  final Completer<void>? stopCompleter;
  String? stoppedSessionId;

  @override
  Future<ActiveRecordingSession?> restoreActiveSession() async => activeSession;

  @override
  Future<void> stopSession({required String sessionId}) {
    stoppedSessionId = sessionId;
    return stopCompleter?.future ?? Future<void>.value();
  }
}
