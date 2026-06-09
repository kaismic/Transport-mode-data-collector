import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/features/upload/models/upload_exception.dart';
import 'package:transport_data_collector/features/upload/services/pending_confirmation_retry_service.dart';
import 'package:transport_data_collector/features/upload/services/upload_service.dart';

void main() {
  late AppDatabase database;
  late _FakeUploadService uploadService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    uploadService = _FakeUploadService();
  });

  tearDown(() => database.close());

  test(
    'clears successful confirmations and leaves failed ones pending',
    () async {
      await _insertSession(
        database,
        id: 'confirmed-session',
        confirmPending: true,
        uploadedAtMs: 2000,
      );
      await _insertSession(
        database,
        id: 'failed-session',
        confirmPending: true,
        uploadedAtMs: 3000,
      );
      await _insertSession(
        database,
        id: 'ordinary-session',
        confirmPending: false,
        uploadedAtMs: 4000,
      );
      uploadService.failedSessionIds.add('failed-session');

      final result = await PendingConfirmationRetryService(
        database: database,
        uploadService: uploadService,
      ).retryPendingConfirmations();

      expect(result.attempted, 2);
      expect(result.confirmed, 1);
      expect(result.stillPending, 1);
      expect(uploadService.confirmedSessionIds, [
        'confirmed-session',
        'failed-session',
      ]);
      expect(
        (await database.sessionDao.getSession(
          'confirmed-session',
        ))!.confirmPending,
        isFalse,
      );
      expect(
        (await database.sessionDao.getSession(
          'failed-session',
        ))!.confirmPending,
        isTrue,
      );
    },
  );
}

Future<void> _insertSession(
  AppDatabase database, {
  required String id,
  required bool confirmPending,
  required int uploadedAtMs,
}) {
  return database.sessionDao.insertSession(
    SessionsCompanion.insert(
      id: id,
      deviceUuid: 'device-id',
      vehicleType: 'car',
      startedAtMs: 1000,
      stoppedAtMs: const Value(1500),
      uploadedAtMs: Value(uploadedAtMs),
      sensorManifest: '{}',
      confirmPending: Value(confirmPending),
    ),
  );
}

class _FakeUploadService extends UploadService {
  final failedSessionIds = <String>{};
  final confirmedSessionIds = <String>[];

  @override
  Future<void> confirmUpload({
    required String sessionId,
    required int uploadedAtMs,
  }) async {
    confirmedSessionIds.add(sessionId);
    if (failedSessionIds.contains(sessionId)) {
      throw const ConfirmException('Still offline');
    }
  }
}
