import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [Sessions, Samples])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  Future<void> insertSession(SessionsCompanion session) {
    return into(sessions).insert(session);
  }

  Stream<List<Session>> watchAllSessions() {
    return (select(
      sessions,
    )..orderBy([(t) => OrderingTerm.desc(t.startedAtMs)])).watch();
  }

  Future<List<Session>> getAllSessions() {
    return (select(
      sessions,
    )..orderBy([(t) => OrderingTerm.desc(t.startedAtMs)])).get();
  }

  Future<Session?> getSession(String id) {
    return (select(sessions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<Session>> getConfirmPendingSessions() {
    return (select(sessions)..where(
          (t) => t.confirmPending.equals(true) & t.uploadedAtMs.isNotNull(),
        ))
        .get();
  }

  Future<void> markStopped({
    required String id,
    required int stoppedAtMs,
    required String sensorManifest,
  }) {
    return (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        stoppedAtMs: Value(stoppedAtMs),
        trimmedEndMs: Value(stoppedAtMs),
        sensorManifest: Value(sensorManifest),
      ),
    );
  }

  Future<int> markStopObserved({required String id, required int stoppedAtMs}) {
    return customUpdate(
      '''
UPDATE sessions
SET
  stopped_at_ms = COALESCE(stopped_at_ms, ?),
  trimmed_end_ms = COALESCE(trimmed_end_ms, stopped_at_ms, ?)
WHERE id = ?
''',
      variables: [
        Variable<int>(stoppedAtMs),
        Variable<int>(stoppedAtMs),
        Variable<String>(id),
      ],
      updates: {sessions},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> updateTrim({
    required String id,
    required int trimmedStartMs,
    required int trimmedEndMs,
  }) {
    return (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        trimmedStartMs: Value(trimmedStartMs),
        trimmedEndMs: Value(trimmedEndMs),
      ),
    );
  }

  Future<void> updatePhonePosition({
    required String id,
    required String phonePosition,
  }) {
    return (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(phonePosition: Value(phonePosition)),
    );
  }

  Future<void> markUploaded({
    required String id,
    required int uploadedAtMs,
    bool confirmPending = false,
  }) {
    return (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        uploadedAtMs: Value(uploadedAtMs),
        confirmPending: Value(confirmPending),
      ),
    );
  }

  Future<void> clearConfirmPending(String id) {
    return (update(sessions)..where((t) => t.id.equals(id))).write(
      const SessionsCompanion(confirmPending: Value(false)),
    );
  }

  Future<void> deleteSessionWithSamples(String id) {
    return transaction(() async {
      await (delete(samples)..where((t) => t.sessionId.equals(id))).go();
      await (delete(sessions)..where((t) => t.id.equals(id))).go();
    });
  }
}
