import 'package:flutter/material.dart';

import '../../../core/invite_code_store.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.inviteCodeStore,
    this.initialSetup = false,
    this.onSaved,
  });

  final InviteCodeStore inviteCodeStore;
  final bool initialSetup;
  final VoidCallback? onSaved;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _inviteCode;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _inviteCode = widget.inviteCodeStore.inviteCode ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.initialSetup,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.initialSetup,
          title: Text(widget.initialSetup ? 'Set Up' : 'Participant Setup'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.key, size: 40),
                const SizedBox(height: 20),
                Text(
                  'Invite Code',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _inviteCode,
                  autofocus: true,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter an invite code';
                    }
                    return null;
                  },
                  onChanged: (value) => _inviteCode = value,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(widget.initialSetup ? 'Continue' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.inviteCodeStore.save(_inviteCode);
      if (!mounted) return;
      widget.onSaved?.call();
      if (!widget.initialSetup) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
