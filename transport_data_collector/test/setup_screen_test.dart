import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport_data_collector/core/invite_code_store.dart';
import 'package:transport_data_collector/features/setup/screens/setup_screen.dart';

void main() {
  testWidgets('first-run setup saves the invite code and completes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await InviteCodeStore.load();
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          inviteCodeStore: store,
          initialSetup: true,
          onSaved: () => completed = true,
        ),
      ),
    );

    expect(find.text('Set Up'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.enterText(find.byType(TextFormField), '  kais-7f3q-22  ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(store.inviteCode, 'KAIS-7F3Q-22');
    expect(completed, isTrue);
  });
}
