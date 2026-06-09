import 'package:drift/drift.dart';

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get deviceUuid => text()();
  TextColumn get vehicleType => text()();
  IntColumn get startedAtMs => integer()();
  IntColumn get stoppedAtMs => integer().nullable()();
  IntColumn get trimmedStartMs => integer().nullable()();
  IntColumn get trimmedEndMs => integer().nullable()();
  IntColumn get uploadedAtMs => integer().nullable()();
  TextColumn get sensorManifest => text()();
  BoolColumn get confirmPending =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Samples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  IntColumn get timestampMs => integer()();
  RealColumn get accelX => real()();
  RealColumn get accelY => real()();
  RealColumn get accelZ => real()();
  RealColumn get gyroX => real()();
  RealColumn get gyroY => real()();
  RealColumn get gyroZ => real()();
  RealColumn get magX => real().nullable()();
  RealColumn get magY => real().nullable()();
  RealColumn get magZ => real().nullable()();
  RealColumn get pressure => real().nullable()();
}
