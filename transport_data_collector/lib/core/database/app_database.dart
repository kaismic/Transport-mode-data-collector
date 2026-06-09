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
  int get schemaVersion => 1;
}
