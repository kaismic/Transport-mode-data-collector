import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/database/app_database.dart';
import 'core/device_id.dart';
import 'core/invite_code_store.dart';
import 'features/home/screens/home_screen.dart';
import 'features/recording/bloc/recording_bloc.dart';
import 'features/recording/services/recording_service.dart';
import 'features/setup/screens/setup_screen.dart';
import 'features/upload/bloc/upload_bloc.dart';
import 'features/upload/services/pending_confirmation_retry_service.dart';
import 'features/upload/services/upload_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  RecordingService.initForegroundTask();

  final database = AppDatabase();
  final deviceUuid = await DeviceId.get();
  final inviteCodeStore = await InviteCodeStore.load();
  final uploadService = UploadService();

  runApp(
    TransportDataCollectorApp(
      database: database,
      deviceUuid: deviceUuid,
      inviteCodeStore: inviteCodeStore,
      uploadService: uploadService,
    ),
  );

  unawaited(
    _retryPendingConfirmations(
      database: database,
      uploadService: uploadService,
    ),
  );
}

Future<void> _retryPendingConfirmations({
  required AppDatabase database,
  required UploadService uploadService,
}) async {
  try {
    await PendingConfirmationRetryService(
      database: database,
      uploadService: uploadService,
    ).retryPendingConfirmations();
  } catch (error, stackTrace) {
    debugPrint('Pending upload confirmation retry failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class TransportDataCollectorApp extends StatelessWidget {
  const TransportDataCollectorApp({
    super.key,
    required this.database,
    required this.deviceUuid,
    required this.inviteCodeStore,
    required this.uploadService,
  });

  final AppDatabase database;
  final String deviceUuid;
  final InviteCodeStore inviteCodeStore;
  final UploadService uploadService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppDatabase>.value(value: database),
        RepositoryProvider<InviteCodeStore>.value(value: inviteCodeStore),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => RecordingBloc(
              recordingService: RecordingService(database),
              deviceUuid: deviceUuid,
            ),
          ),
          BlocProvider(
            create: (_) =>
                UploadBloc(database: database, uploadService: uploadService),
          ),
        ],
        child: MaterialApp(
          title: 'Transport Data Collector',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF006D77),
            ),
            useMaterial3: true,
          ),
          home: _AppEntry(
            deviceUuid: deviceUuid,
            inviteCodeStore: inviteCodeStore,
          ),
        ),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({required this.deviceUuid, required this.inviteCodeStore});

  final String deviceUuid;
  final InviteCodeStore inviteCodeStore;

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  @override
  Widget build(BuildContext context) {
    if (!widget.inviteCodeStore.hasInviteCode) {
      return SetupScreen(
        inviteCodeStore: widget.inviteCodeStore,
        initialSetup: true,
        onSaved: () => setState(() {}),
      );
    }

    return WithForegroundTask(child: HomeScreen(deviceUuid: widget.deviceUuid));
  }
}
