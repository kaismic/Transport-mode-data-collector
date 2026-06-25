import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/core/invite_code_store.dart';
import 'package:transport_data_collector/core/time_format.dart';
import 'package:transport_data_collector/features/review/screens/review_list_screen.dart';
import 'package:transport_data_collector/features/upload/bloc/upload_bloc.dart';
import 'package:transport_data_collector/features/upload/models/upload_payload.dart';
import 'package:transport_data_collector/features/upload/services/upload_service.dart';

void main() {
  late AppDatabase database;
  late InviteCodeStore inviteCodeStore;

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Transport Data Collector',
      packageName: 'transport_data_collector',
      version: '1.0.1',
      buildNumber: '2',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({'invite_code': 'KAIS-TEST'});
    inviteCodeStore = await InviteCodeStore.load();
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('session stream emits a stopped row with a fixed duration', () async {
    const startedAtMs = 1000;
    const stoppedAtMs = 11000;
    await database.sessionDao.insertSession(
      SessionsCompanion.insert(
        id: 'session-id',
        deviceUuid: 'device-id',
        vehicleType: 'car',
        startedAtMs: startedAtMs,
        sensorManifest: '{}',
      ),
    );
    final stoppedSession = database.sessionDao
        .watchAllSessions()
        .expand((sessions) => sessions)
        .firstWhere((session) => session.stoppedAtMs != null);

    await database.sessionDao.markStopped(
      id: 'session-id',
      stoppedAtMs: stoppedAtMs,
      sensorManifest: '{}',
    );

    final session = await stoppedSession;
    expect(session.stoppedAtMs, stoppedAtMs);
    expect(
      sessionDuration(
        startedAtMs: session.startedAtMs,
        stoppedAtMs: session.stoppedAtMs,
      ),
      const Duration(seconds: 10),
    );
  });

  testWidgets('upload all requires confirmation before uploading', (
    tester,
  ) async {
    await _insertPendingSession(database);
    final uploadService = _RecordingUploadService();

    await _pumpReviewListScreen(
      tester,
      database: database,
      inviteCodeStore: inviteCodeStore,
      uploadService: uploadService,
    );

    await tester.tap(find.byKey(const Key('upload-all-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Upload all sessions?'), findsOneWidget);
    expect(
      find.text('This will upload 1 pending session. Continue?'),
      findsOneWidget,
    );
    expect(uploadService.uploadedSessionIds, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(uploadService.uploadedSessionIds, isEmpty);

    await tester.tap(find.byKey(const Key('upload-all-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Upload All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(uploadService.uploadedSessionIds, ['session-id']);
    expect(uploadService.inviteCodes, ['KAIS-TEST']);

    await _disposeReviewListScreen(tester);
  });
}

Future<void> _pumpReviewListScreen(
  WidgetTester tester, {
  required AppDatabase database,
  required InviteCodeStore inviteCodeStore,
  required UploadService uploadService,
}) async {
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: database),
        RepositoryProvider<InviteCodeStore>.value(value: inviteCodeStore),
      ],
      child: BlocProvider(
        create: (_) =>
            UploadBloc(database: database, uploadService: uploadService),
        child: const MaterialApp(home: ReviewListScreen()),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byKey(const Key('upload-all-button')).evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _disposeReviewListScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _insertPendingSession(AppDatabase database) {
  return database.sessionDao.insertSession(
    SessionsCompanion.insert(
      id: 'session-id',
      deviceUuid: 'device-id',
      vehicleType: 'car',
      startedAtMs: 1000,
      stoppedAtMs: const Value(2000),
      trimmedEndMs: const Value(2000),
      sensorManifest: '{}',
    ),
  );
}

class _RecordingUploadService extends UploadService {
  final uploadedSessionIds = <String>[];
  final inviteCodes = <String>[];

  @override
  Future<void> uploadSession({
    required UploadPayload payload,
    required String inviteCode,
  }) async {
    uploadedSessionIds.add(payload.sessionId);
    inviteCodes.add(inviteCode);
  }
}
