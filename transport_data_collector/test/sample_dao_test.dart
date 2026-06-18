import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.sessionDao.insertSession(
      SessionsCompanion.insert(
        id: 'session-id',
        deviceUuid: 'device-id',
        vehicleType: 'car',
        startedAtMs: 1000,
        stoppedAtMs: const Value(200000),
        sensorManifest: '{}',
      ),
    );
  });

  tearDown(() => database.close());

  test('review overview handles an empty session', () async {
    final overview = await database.sampleDao
        .watchReviewSampleOverview('session-id')
        .first;

    expect(overview.sampleCount, 0);
    expect(overview.points, isEmpty);
  });

  test('review overview handles a single sample', () async {
    await database.sampleDao.insertSamples([_sample(0)]);

    final overview = await database.sampleDao
        .watchReviewSampleOverview('session-id')
        .first;

    expect(overview.sampleCount, 1);
    expect(overview.points, hasLength(1));
    expect(overview.points.single.timestampMs, 1000);
  });

  test(
    'review overview bounds chart points and preserves exact count',
    () async {
      await database.sampleDao.insertSamples([
        for (var index = 0; index < 1200; index++) _sample(index),
      ]);

      final overview = await database.sampleDao
          .watchReviewSampleOverview('session-id')
          .first;

      expect(overview.sampleCount, 1200);
      expect(overview.points, hasLength(500));
      expect(overview.points.first.timestampMs, 1000);
      expect(overview.points.last.timestampMs, 2199);
    },
  );

  test('review overview emits when late samples arrive', () async {
    final emissions = database.sampleDao
        .watchReviewSampleOverview('session-id')
        .take(2)
        .toList();

    await Future<void>.delayed(Duration.zero);
    await database.sampleDao.insertSamples([_sample(0)]);

    final overviews = await emissions;
    expect(overviews.first.sampleCount, 0);
    expect(overviews.last.sampleCount, 1);
  });
}

SamplesCompanion _sample(int index) {
  return SamplesCompanion.insert(
    sessionId: 'session-id',
    timestampMs: 1000 + index,
    accelX: index.toDouble(),
    accelY: 2,
    accelZ: 3,
    gyroX: 0,
    gyroY: 0,
    gyroZ: 0,
  );
}
