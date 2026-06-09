import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/database/app_database.dart';
import 'core/device_id.dart';
import 'features/home/screens/home_screen.dart';
import 'features/recording/bloc/recording_bloc.dart';
import 'features/recording/services/recording_service.dart';
import 'features/upload/bloc/upload_bloc.dart';
import 'features/upload/services/pending_confirmation_retry_service.dart';
import 'features/upload/services/upload_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  RecordingService.initForegroundTask();

  final database = AppDatabase();
  final deviceUuid = await DeviceId.get();
  final uploadService = UploadService();

  runApp(
    TransportDataCollectorApp(
      database: database,
      deviceUuid: deviceUuid,
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
    required this.uploadService,
  });

  final AppDatabase database;
  final String deviceUuid;
  final UploadService uploadService;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AppDatabase>.value(
      value: database,
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
          home: WithForegroundTask(child: HomeScreen(deviceUuid: deviceUuid)),
        ),
      ),
    );
  }
}
