import 'package:shared_preferences/shared_preferences.dart';

class InviteCodeStore {
  InviteCodeStore._(this._preferences, this._inviteCode);

  static const _key = 'invite_code';

  final SharedPreferences _preferences;
  String? _inviteCode;

  static Future<InviteCodeStore> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedCode = preferences.getString(_key)?.trim().toUpperCase();
    return InviteCodeStore._(
      preferences,
      savedCode == null || savedCode.isEmpty ? null : savedCode,
    );
  }

  String? get inviteCode => _inviteCode;

  bool get hasInviteCode => _inviteCode != null;

  Future<void> save(String inviteCode) async {
    final normalized = inviteCode.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(inviteCode, 'inviteCode', 'Must not be empty');
    }
    await _preferences.setString(_key, normalized);
    _inviteCode = normalized;
  }
}
