import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport_data_collector/core/database/app_database.dart';
import 'package:transport_data_collector/core/invite_code_store.dart';
import 'package:transport_data_collector/features/review/screens/session_review_screen.dart';
import 'package:transport_data_collector/features/upload/bloc/upload_bloc.dart';
import 'package:transport_data_collector/features/upload/models/upload_payload.dart';
import 'package:transport_data_collector/features/upload/services/upload_service.dart';

void main() {
  late AppDatabase database;
  late InviteCodeStore inviteCodeStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'invite_code': 'KAIS-TEST'});
    inviteCodeStore = await InviteCodeStore.load();
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('uploaded sessions cannot be trimmed, uploaded, or deleted', (
    tester,
  ) async {
    await _insertSession(database, uploadedAtMs: 3000);

    await _pumpReviewScreen(
      tester,
      database: database,
      inviteCodeStore: inviteCodeStore,
      uploadService: _CompletingUploadService(),
    );

    expect(
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Uploaded'))
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(find.text('Delete'), 200);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Delete'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('upload button shows progress and locks controls immediately', (
    tester,
  ) async {
    await _insertSession(database);
    final uploadService = _CompletingUploadService();

    await _pumpReviewScreen(
      tester,
      database: database,
      inviteCodeStore: inviteCodeStore,
      uploadService: uploadService,
    );

    await tester.scrollUntilVisible(find.text('Confirm & Upload'), 200);
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm & Upload'));
    await tester.pump();

    expect(find.text('Uploading...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Uploading...'),
          )
          .onPressed,
      isNull,
    );

    uploadService.complete();
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpReviewScreen(
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
        child: const MaterialApp(
          home: SessionReviewScreen(sessionId: 'session-id'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _insertSession(AppDatabase database, {int? uploadedAtMs}) async {
  await database.sessionDao.insertSession(
    SessionsCompanion.insert(
      id: 'session-id',
      deviceUuid: 'device-id',
      vehicleType: 'car',
      startedAtMs: 1000,
      stoppedAtMs: const Value(2000),
      trimmedEndMs: const Value(2000),
      uploadedAtMs: Value(uploadedAtMs),
      sensorManifest: '{}',
    ),
  );
}

class _CompletingUploadService extends UploadService {
  final _completer = Completer<void>();

  @override
  Future<void> uploadSession({
    required UploadPayload payload,
    required String inviteCode,
  }) {
    return _completer.future;
  }

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
