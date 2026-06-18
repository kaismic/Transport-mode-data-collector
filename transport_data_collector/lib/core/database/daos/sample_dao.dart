import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'sample_dao.g.dart';

class ReviewSamplePoint {
  const ReviewSamplePoint({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });

  final int timestampMs;
  final double accelX;
  final double accelY;
  final double accelZ;
}

class ReviewSampleOverview {
  const ReviewSampleOverview({required this.sampleCount, required this.points});

  final int sampleCount;
  final List<ReviewSamplePoint> points;
}

@DriftAccessor(tables: [Samples])
class SampleDao extends DatabaseAccessor<AppDatabase> with _$SampleDaoMixin {
  SampleDao(super.db);

  Future<void> insertSamples(List<SamplesCompanion> sampleRows) {
    if (sampleRows.isEmpty) return Future.value();
    return batch((b) => b.insertAll(samples, sampleRows));
  }

  Future<List<Sample>> getSamplesForSession(String sessionId) {
    return (select(samples)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestampMs)]))
        .get();
  }

  Stream<List<Sample>> watchSamplesForSession(String sessionId) {
    return (select(samples)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestampMs)]))
        .watch();
  }

  Stream<ReviewSampleOverview> watchReviewSampleOverview(
    String sessionId, {
    int maxPoints = 500,
  }) {
    if (maxPoints < 1) {
      throw ArgumentError.value(maxPoints, 'maxPoints', 'Must be positive.');
    }
    return customSelect(
      '''
WITH RECURSIVE
sample_stats AS (
  SELECT
    COUNT(*) AS sample_count,
    MIN(timestamp_ms) AS min_timestamp_ms,
    MAX(timestamp_ms) AS max_timestamp_ms
  FROM samples
  WHERE session_id = ?
),
targets(point_index, target_timestamp_ms) AS (
  SELECT 0, min_timestamp_ms
  FROM sample_stats
  WHERE sample_count > 0

  UNION ALL

  SELECT
    point_index + 1,
    min_timestamp_ms +
      ((max_timestamp_ms - min_timestamp_ms) * (point_index + 1)) /
      (CASE
        WHEN sample_count < ? THEN sample_count
        ELSE ?
      END - 1)
  FROM targets, sample_stats
  WHERE
    point_index + 1 <
      CASE WHEN sample_count < ? THEN sample_count ELSE ? END
),
sampled_ids AS (
  SELECT DISTINCT (
    SELECT id
    FROM samples
    WHERE
      session_id = ?
      AND timestamp_ms >= targets.target_timestamp_ms
    ORDER BY timestamp_ms
    LIMIT 1
  ) AS sample_id
  FROM targets
)
SELECT
  sample_stats.sample_count,
  samples.timestamp_ms,
  samples.accel_x,
  samples.accel_y,
  samples.accel_z
FROM sample_stats
LEFT JOIN sampled_ids ON TRUE
LEFT JOIN samples ON samples.id = sampled_ids.sample_id
ORDER BY samples.timestamp_ms
''',
      variables: [
        Variable<String>(sessionId),
        Variable<int>(maxPoints),
        Variable<int>(maxPoints),
        Variable<int>(maxPoints),
        Variable<int>(maxPoints),
        Variable<String>(sessionId),
      ],
      readsFrom: {samples},
    ).watch().map((rows) {
      final sampleCount = rows.first.read<int>('sample_count');
      final points = <ReviewSamplePoint>[
        for (final row in rows)
          if (row.readNullable<int>('timestamp_ms') case final timestampMs?)
            ReviewSamplePoint(
              timestampMs: timestampMs,
              accelX: row.read<double>('accel_x'),
              accelY: row.read<double>('accel_y'),
              accelZ: row.read<double>('accel_z'),
            ),
      ];
      return ReviewSampleOverview(sampleCount: sampleCount, points: points);
    });
  }
}
