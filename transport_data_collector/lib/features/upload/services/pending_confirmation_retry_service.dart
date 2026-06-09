import '../../../core/database/app_database.dart';
import '../models/upload_exception.dart';
import 'upload_service.dart';

class PendingConfirmationRetryService {
  const PendingConfirmationRetryService({
    required this.database,
    required this.uploadService,
  });

  final AppDatabase database;
  final UploadService uploadService;

  Future<PendingConfirmationRetryResult> retryPendingConfirmations() async {
    final pendingSessions = await database.sessionDao
        .getConfirmPendingSessions();
    var confirmed = 0;

    for (final session in pendingSessions) {
      final uploadedAtMs = session.uploadedAtMs;
      if (uploadedAtMs == null) continue;

      try {
        await uploadService.confirmUpload(
          sessionId: session.id,
          uploadedAtMs: uploadedAtMs,
        );
        await database.sessionDao.clearConfirmPending(session.id);
        confirmed++;
      } on ConfirmException {
        // Keep the flag set so this session can be retried on the next launch.
      }
    }

    return PendingConfirmationRetryResult(
      attempted: pendingSessions.length,
      confirmed: confirmed,
    );
  }
}

class PendingConfirmationRetryResult {
  const PendingConfirmationRetryResult({
    required this.attempted,
    required this.confirmed,
  });

  final int attempted;
  final int confirmed;

  int get stillPending => attempted - confirmed;
}
