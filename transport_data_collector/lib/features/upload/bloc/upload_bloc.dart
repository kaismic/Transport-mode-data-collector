import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/app_database.dart';
import '../models/upload_exception.dart';
import '../models/upload_payload.dart';
import '../services/upload_service.dart';

sealed class UploadEvent extends Equatable {
  const UploadEvent();

  @override
  List<Object?> get props => [];
}

class UploadSessionRequested extends UploadEvent {
  const UploadSessionRequested({
    required this.sessionId,
    required this.inviteCode,
  });

  final String sessionId;
  final String inviteCode;

  @override
  List<Object?> get props => [sessionId, inviteCode];
}

class UploadAllRequested extends UploadEvent {
  const UploadAllRequested({required this.inviteCode});

  final String inviteCode;

  @override
  List<Object?> get props => [inviteCode];
}

sealed class UploadState extends Equatable {
  const UploadState();

  @override
  List<Object?> get props => [];
}

class UploadIdle extends UploadState {
  const UploadIdle();
}

class UploadInProgress extends UploadState {
  const UploadInProgress(this.sessionId);

  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

class UploadSuccess extends UploadState {
  const UploadSuccess(this.sessionId);

  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

class UploadConfirmPending extends UploadState {
  const UploadConfirmPending(this.sessionId);

  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

class UploadFailure extends UploadState {
  const UploadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class UploadBatchInProgress extends UploadState {
  const UploadBatchInProgress({
    required this.completed,
    required this.total,
    required this.currentSessionId,
  });

  final int completed;
  final int total;
  final String currentSessionId;

  @override
  List<Object?> get props => [completed, total, currentSessionId];
}

class UploadBatchComplete extends UploadState {
  const UploadBatchComplete({
    required this.uploaded,
    required this.confirmPending,
    required this.failed,
  });

  final int uploaded;
  final int confirmPending;
  final int failed;

  int get total => uploaded + confirmPending + failed;

  @override
  List<Object?> get props => [uploaded, confirmPending, failed];
}

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  UploadBloc({required this.database, required this.uploadService})
    : super(const UploadIdle()) {
    on<UploadSessionRequested>(_onUploadRequested);
    on<UploadAllRequested>(_onUploadAllRequested);
  }

  final AppDatabase database;
  final UploadService uploadService;

  Future<void> _onUploadRequested(
    UploadSessionRequested event,
    Emitter<UploadState> emit,
  ) async {
    emit(UploadInProgress(event.sessionId));
    try {
      final outcome = await _uploadSession(
        sessionId: event.sessionId,
        inviteCode: event.inviteCode,
      );
      switch (outcome) {
        case _UploadOutcome.uploaded:
          emit(UploadSuccess(event.sessionId));
        case _UploadOutcome.confirmPending:
          emit(UploadConfirmPending(event.sessionId));
      }
    } on UploadException catch (error) {
      emit(UploadFailure(error.message));
    } catch (error) {
      emit(UploadFailure(error.toString()));
    }
  }

  Future<void> _onUploadAllRequested(
    UploadAllRequested event,
    Emitter<UploadState> emit,
  ) async {
    final sessions = (await database.sessionDao.getAllSessions())
        .where(
          (session) =>
              session.stoppedAtMs != null && session.uploadedAtMs == null,
        )
        .toList();
    var uploaded = 0;
    var confirmPending = 0;
    var failed = 0;

    for (var index = 0; index < sessions.length; index++) {
      final session = sessions[index];
      emit(
        UploadBatchInProgress(
          completed: index,
          total: sessions.length,
          currentSessionId: session.id,
        ),
      );
      try {
        final outcome = await _uploadSession(
          sessionId: session.id,
          inviteCode: event.inviteCode,
        );
        switch (outcome) {
          case _UploadOutcome.uploaded:
            uploaded++;
          case _UploadOutcome.confirmPending:
            confirmPending++;
        }
      } catch (_) {
        failed++;
      }
    }

    emit(
      UploadBatchComplete(
        uploaded: uploaded,
        confirmPending: confirmPending,
        failed: failed,
      ),
    );
  }

  Future<_UploadOutcome> _uploadSession({
    required String sessionId,
    required String inviteCode,
  }) async {
    final session = await database.sessionDao.getSession(sessionId);
    if (session == null) {
      throw StateError('Session not found.');
    }
    if (session.uploadedAtMs != null) {
      throw StateError('Session has already been uploaded.');
    }
    final samples = await database.sampleDao.getSamplesForSession(sessionId);
    final appVersion = await _currentAppVersion();
    final payload = UploadPayload.fromSessionAndSamples(
      session: session,
      samples: samples,
      appVersion: appVersion,
    );
    try {
      await uploadService.uploadSession(
        payload: payload,
        inviteCode: inviteCode,
      );
      await database.sessionDao.markUploaded(
        id: sessionId,
        uploadedAtMs: payload.uploadedAtMs,
      );
      return _UploadOutcome.uploaded;
    } on ConfirmException {
      await database.sessionDao.markUploaded(
        id: sessionId,
        uploadedAtMs: payload.uploadedAtMs,
        confirmPending: true,
      );
      return _UploadOutcome.confirmPending;
    }
  }
}

enum _UploadOutcome { uploaded, confirmPending }

Future<String> _currentAppVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (packageInfo.buildNumber.isEmpty) return packageInfo.version;
  return '${packageInfo.version}+${packageInfo.buildNumber}';
}
