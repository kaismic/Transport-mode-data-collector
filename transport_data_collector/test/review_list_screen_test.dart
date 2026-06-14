import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/core/time_format.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('session stream emits a stopped row with a fixed duration', () async {
    const startedAtMs = 1000;
    const stoppedAtMs = 11000;
    await database.sessionDao.insertSession(
      SessionsCompanion.insert(
        id: 'session-id',
        deviceUuid: 'device-id',
        vehicleType: 'car',
        startedAtMs: startedAtMs,
        sensorManifest: '{}',
      ),
    );
    final stoppedSession = database.sessionDao
        .watchAllSessions()
        .expand((sessions) => sessions)
        .firstWhere((session) => session.stoppedAtMs != null);

    await database.sessionDao.markStopped(
      id: 'session-id',
      stoppedAtMs: stoppedAtMs,
      sensorManifest: '{}',
    );

    final session = await stoppedSession;
    expect(session.stoppedAtMs, stoppedAtMs);
    expect(
      sessionDuration(
        startedAtMs: session.startedAtMs,
        stoppedAtMs: session.stoppedAtMs,
      ),
      const Duration(seconds: 10),
    );
  });
}
