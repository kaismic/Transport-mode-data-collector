import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/recording_service.dart';

sealed class RecordingEvent extends Equatable {
  const RecordingEvent();

  @override
  List<Object?> get props => [];
}

class StartRecordingRequested extends RecordingEvent {
  const StartRecordingRequested(this.vehicleType);

  final String vehicleType;

  @override
  List<Object?> get props => [vehicleType];
}

class StopRecordingRequested extends RecordingEvent {
  const StopRecordingRequested();
}

class RestoreRecordingRequested extends RecordingEvent {
  const RestoreRecordingRequested();
}

class _RecordingTicked extends RecordingEvent {
  const _RecordingTicked();
}

sealed class RecordingState extends Equatable {
  const RecordingState();

  @override
  List<Object?> get props => [];
}

class RecordingIdle extends RecordingState {
  const RecordingIdle();
}

class RecordingStarting extends RecordingState {
  const RecordingStarting();
}

class RecordingRestoring extends RecordingState {
  const RecordingRestoring();
}

class RecordingActive extends RecordingState {
  const RecordingActive({
    required this.sessionId,
    required this.vehicleType,
    required this.startedAtMs,
    required this.elapsed,
  });

  final String sessionId;
  final String vehicleType;
  final int startedAtMs;
  final Duration elapsed;

  @override
  List<Object?> get props => [sessionId, vehicleType, startedAtMs, elapsed];
}

class RecordingError extends RecordingState {
  const RecordingError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  RecordingBloc({required this.recordingService, required this.deviceUuid})
    : super(const RecordingRestoring()) {
    on<StartRecordingRequested>(_onStartRequested);
    on<StopRecordingRequested>(_onStopRequested);
    on<RestoreRecordingRequested>(_onRestoreRequested);
    on<_RecordingTicked>(_onTicked);
    add(const RestoreRecordingRequested());
  }

  final RecordingService recordingService;
  final String deviceUuid;
  Timer? _timer;

  Future<void> _onRestoreRequested(
    RestoreRecordingRequested event,
    Emitter<RecordingState> emit,
  ) async {
    try {
      final activeSession = await recordingService.restoreActiveSession();
      if (activeSession == null) {
        _timer?.cancel();
        emit(const RecordingIdle());
        return;
      }

      _startTimer();
      emit(
        RecordingActive(
          sessionId: activeSession.sessionId,
          vehicleType: activeSession.vehicleType,
          startedAtMs: activeSession.startedAtMs,
          elapsed: _elapsedSince(activeSession.startedAtMs),
        ),
      );
    } catch (error) {
      _timer?.cancel();
      emit(RecordingError('Could not restore active recording: $error'));
      emit(const RecordingIdle());
    }
  }

  Future<void> _onStartRequested(
    StartRecordingRequested event,
    Emitter<RecordingState> emit,
  ) async {
    emit(const RecordingStarting());
    try {
      final sessionId = await recordingService.startSession(
        deviceUuid: deviceUuid,
        vehicleType: event.vehicleType,
      );
      final startedAtMs = DateTime.now().millisecondsSinceEpoch;
      _startTimer();
      emit(
        RecordingActive(
          sessionId: sessionId,
          vehicleType: event.vehicleType,
          startedAtMs: startedAtMs,
          elapsed: Duration.zero,
        ),
      );
    } catch (error) {
      emit(RecordingError(error.toString()));
      emit(const RecordingIdle());
    }
  }

  Future<void> _onStopRequested(
    StopRecordingRequested event,
    Emitter<RecordingState> emit,
  ) async {
    await recordingService.stopSession();
    _timer?.cancel();
    emit(const RecordingIdle());
  }

  void _onTicked(_RecordingTicked event, Emitter<RecordingState> emit) {
    final current = state;
    if (current is! RecordingActive) return;
    final elapsed = _elapsedSince(current.startedAtMs);
    emit(
      RecordingActive(
        sessionId: current.sessionId,
        vehicleType: current.vehicleType,
        startedAtMs: current.startedAtMs,
        elapsed: elapsed,
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const _RecordingTicked()),
    );
  }

  Duration _elapsedSince(int startedAtMs) {
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMs;
    return Duration(milliseconds: elapsedMs < 0 ? 0 : elapsedMs);
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    return super.close();
  }
}
