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
}

class _FakeRecordingService extends RecordingService {
  _FakeRecordingService(super.database, {this.activeSession});

  final ActiveRecordingSession? activeSession;

  @override
  Future<ActiveRecordingSession?> restoreActiveSession() async => activeSession;
}
