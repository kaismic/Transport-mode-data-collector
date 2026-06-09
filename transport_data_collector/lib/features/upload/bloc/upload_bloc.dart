import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  UploadBloc({required this.database, required this.uploadService})
    : super(const UploadIdle()) {
    on<UploadSessionRequested>(_onUploadRequested);
  }

  final AppDatabase database;
  final UploadService uploadService;

  Future<void> _onUploadRequested(
    UploadSessionRequested event,
    Emitter<UploadState> emit,
  ) async {
    emit(UploadInProgress(event.sessionId));
    UploadPayload? payload;
    try {
      final session = await database.sessionDao.getSession(event.sessionId);
      if (session == null) {
        throw StateError('Session not found.');
      }
      final samples = await database.sampleDao.getSamplesForSession(
        event.sessionId,
      );
      payload = UploadPayload.fromSessionAndSamples(
        session: session,
        samples: samples,
      );
      await uploadService.uploadSession(
        payload: payload,
        inviteCode: event.inviteCode,
      );
      await database.sessionDao.markUploaded(
        id: event.sessionId,
        uploadedAtMs: payload.uploadedAtMs,
      );
      emit(UploadSuccess(event.sessionId));
    } on ConfirmException {
      final session = await database.sessionDao.getSession(event.sessionId);
      if (session != null) {
        await database.sessionDao.markUploaded(
          id: event.sessionId,
          uploadedAtMs:
              payload?.uploadedAtMs ?? DateTime.now().millisecondsSinceEpoch,
          confirmPending: true,
        );
      }
      emit(UploadConfirmPending(event.sessionId));
    } on UploadException catch (error) {
      emit(UploadFailure(error.message));
    } catch (error) {
      emit(UploadFailure(error.toString()));
    }
  }
}
