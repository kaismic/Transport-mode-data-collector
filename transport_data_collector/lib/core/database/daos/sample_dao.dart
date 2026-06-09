import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'sample_dao.g.dart';

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
}
