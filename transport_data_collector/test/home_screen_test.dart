import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/features/home/screens/home_screen.dart';
import 'package:transport_data_collector/features/recording/bloc/recording_bloc.dart';

void main() {
  testWidgets('active recording action becomes a red stop button', (
    tester,
  ) async {
    var started = false;
    var stopped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingActionButton(
            recordingState: const RecordingActive(
              sessionId: 'session-id',
              vehicleType: 'train',
              startedAtMs: 1000,
              elapsed: Duration(seconds: 12),
            ),
            onStartRecording: () => started = true,
            onStopRecording: () => stopped = true,
          ),
        ),
      ),
    );

    expect(find.text('Stop Recording'), findsOneWidget);
    expect(find.text('Start Recording'), findsNothing);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Stop Recording'),
    );
    final backgroundColor = button.style?.backgroundColor?.resolve(
      <WidgetState>{},
    );
    expect(
      backgroundColor,
      Theme.of(
        tester.element(find.byType(RecordingActionButton)),
      ).colorScheme.error,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Stop Recording'));

    expect(stopped, isTrue);
    expect(started, isFalse);
  });

  testWidgets('idle recording action starts from the main button', (
    tester,
  ) async {
    var started = false;
    var stopped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingActionButton(
            recordingState: const RecordingIdle(),
            onStartRecording: () => started = true,
            onStopRecording: () => stopped = true,
          ),
        ),
      ),
    );

    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.text('Stop Recording'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Recording'));

    expect(started, isTrue);
    expect(stopped, isFalse);
  });
}
