// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_dao.dart';

// ignore_for_file: type=lint
mixin _$SampleDaoMixin on DatabaseAccessor<AppDatabase> {
  $SamplesTable get samples => attachedDatabase.samples;
  SampleDaoManager get managers => SampleDaoManager(this);
}

class SampleDaoManager {
  final _$SampleDaoMixin _db;
  SampleDaoManager(this._db);
  $$SamplesTableTableManager get samples =>
      $$SamplesTableTableManager(_db.attachedDatabase, _db.samples);
}
