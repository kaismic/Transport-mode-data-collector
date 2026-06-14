import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/features/upload/bloc/upload_bloc.dart';
import 'package:transport_data_collector/features/upload/models/upload_exception.dart';
import 'package:transport_data_collector/features/upload/models/upload_payload.dart';
import 'package:transport_data_collector/features/upload/services/upload_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'upload all continues after failures and skips ineligible sessions',
    () async {
      await _insertSession(database, id: 'success', stopped: true);
      await _insertSession(database, id: 'confirm', stopped: true);
      await _insertSession(database, id: 'failure', stopped: true);
      await _insertSession(database, id: 'active', stopped: false);
      await _insertSession(
        database,
        id: 'uploaded',
        stopped: true,
        uploadedAtMs: 4000,
      );
      final service = _OutcomeUploadService({
        'confirm': const ConfirmException('confirm failed'),
        'failure': const S3PutException('put failed'),
      });
      final bloc = UploadBloc(database: database, uploadService: service);
      final completed = bloc.stream
          .where((state) => state is UploadBatchComplete)
          .cast<UploadBatchComplete>()
          .first;

      bloc.add(const UploadAllRequested(inviteCode: 'KAIS-TEST'));
      final result = await completed;

      expect(result.uploaded, 1);
      expect(result.confirmPending, 1);
      expect(result.failed, 1);
      expect(service.uploadedSessionIds, {'success', 'confirm', 'failure'});
      expect(
        (await database.sessionDao.getSession('success'))?.uploadedAtMs,
        isNotNull,
      );
      expect(
        (await database.sessionDao.getSession('confirm'))?.confirmPending,
        isTrue,
      );
      expect(
        (await database.sessionDao.getSession('failure'))?.uploadedAtMs,
        isNull,
      );
      expect(
        (await database.sessionDao.getSession('active'))?.uploadedAtMs,
        isNull,
      );
      expect(
        (await database.sessionDao.getSession('uploaded'))?.uploadedAtMs,
        4000,
      );
      await bloc.close();
    },
  );

  test('upload all reports an empty batch when nothing is pending', () async {
    await _insertSession(database, id: 'active', stopped: false);
    final bloc = UploadBloc(
      database: database,
      uploadService: _OutcomeUploadService(const {}),
    );
    final completed = bloc.stream
        .where((state) => state is UploadBatchComplete)
        .cast<UploadBatchComplete>()
        .first;

    bloc.add(const UploadAllRequested(inviteCode: 'KAIS-TEST'));

    expect((await completed).total, 0);
    await bloc.close();
  });
}

Future<void> _insertSession(
  AppDatabase database, {
  required String id,
  required bool stopped,
  int? uploadedAtMs,
}) {
  return database.sessionDao.insertSession(
    SessionsCompanion.insert(
      id: id,
      deviceUuid: 'device-id',
      vehicleType: 'car',
      startedAtMs: 1000,
      stoppedAtMs: stopped ? const Value(2000) : const Value.absent(),
      trimmedEndMs: stopped ? const Value(2000) : const Value.absent(),
      uploadedAtMs: Value(uploadedAtMs),
      sensorManifest: '{}',
    ),
  );
}

class _OutcomeUploadService extends UploadService {
  _OutcomeUploadService(this.outcomes);

  final Map<String, Object> outcomes;
  final uploadedSessionIds = <String>{};

  @override
  Future<void> uploadSession({
    required UploadPayload payload,
    required String inviteCode,
  }) async {
    uploadedSessionIds.add(payload.sessionId);
    final outcome = outcomes[payload.sessionId];
    if (outcome != null) throw outcome;
  }
}
