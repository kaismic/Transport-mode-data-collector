import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport_data_collector/core/invite_code_store.dart';

void main() {
  test('normalizes and persists the invite code', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await InviteCodeStore.load();

    expect(store.hasInviteCode, isFalse);

    await store.save('  kais-7f3q-22  ');
    final reloadedStore = await InviteCodeStore.load();

    expect(store.inviteCode, 'KAIS-7F3Q-22');
    expect(reloadedStore.inviteCode, 'KAIS-7F3Q-22');
  });
}
