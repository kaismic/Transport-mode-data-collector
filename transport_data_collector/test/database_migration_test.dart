import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transport_data_collector/core/database/app_database.dart';

void main() {
  test('schema v1 sessions migrate with other phone position', () async {
    final directory = await Directory.systemTemp.createTemp(
      'transport-data-migration-',
    );
    final file = File('${directory.path}/transport_data.db');
    final oldDatabase = sqlite3.open(file.path);
    oldDatabase.execute('''
CREATE TABLE sessions (
  id TEXT NOT NULL PRIMARY KEY,
  device_uuid TEXT NOT NULL,
  vehicle_type TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  stopped_at_ms INTEGER NULL,
  trimmed_start_ms INTEGER NULL,
  trimmed_end_ms INTEGER NULL,
  uploaded_at_ms INTEGER NULL,
  sensor_manifest TEXT NOT NULL,
  confirm_pending INTEGER NOT NULL DEFAULT 0
)
''');
    oldDatabase.execute(
      '''
INSERT INTO sessions (
  id,
  device_uuid,
  vehicle_type,
  started_at_ms,
  sensor_manifest
) VALUES (?, ?, ?, ?, ?)
''',
      ['session-id', 'device-id', 'car', 1000, '{}'],
    );
    oldDatabase.execute('PRAGMA user_version = 1');
    oldDatabase.dispose();

    final database = AppDatabase.forTesting(NativeDatabase(file));
    final session = await database.sessionDao.getSession('session-id');

    expect(session?.phonePosition, 'other');

    await database.close();
    await directory.delete(recursive: true);
  });
}
