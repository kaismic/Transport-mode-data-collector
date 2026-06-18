import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/sample_dao.dart';
import 'daos/session_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Sessions, Samples], daos: [SessionDao, SampleDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'transport_data.db'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSampleReviewIndex();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(sessions, sessions.phonePosition);
      }
      if (from < 3) {
        await _createSampleReviewIndex();
      }
    },
  );

  Future<void> _createSampleReviewIndex() {
    return customStatement(
      'CREATE INDEX IF NOT EXISTS samples_session_timestamp_idx '
      'ON samples (session_id, timestamp_ms)',
    );
  }
}
