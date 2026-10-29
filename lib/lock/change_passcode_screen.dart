import 'package:flutter/material.dart';

import '../keys.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../vault/master_key_store.dart';

class ChangePasscodeScreen extends StatefulWidget {
  const ChangePasscodeScreen({super.key, required this.store});
  final MasterKeyStore store;
  @override
  State<ChangePasscodeScreen> createState() => _ChangePasscodeScreenState();
}

class _ChangePasscodeScreenState extends State<ChangePasscodeScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_next.text != _confirm.text) {
      setState(() => _error = 'Passcodes do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.changePasscode(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on WrongPasscodeException {
      if (mounted) setState(() => _error = 'Current passcode is incorrect');
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not change passcode. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Change passcode'),
        actions: const [LockButton()],
      ),
      body: FormBody(
        children: [
          const Text('Your captures and recovery key stay the same.'),
          const SizedBox(height: 24),
          for (final field in [
            (Keys.currentPasscode, _current, 'Current passcode'),
            (Keys.newPasscode, _next, 'New passcode'),
            (Keys.confirmPasscode, _confirm, 'Confirm new passcode'),
          ]) ...[
            TextField(
              key: field.$1,
              controller: field.$2,
              onChanged: (_) => PrivacyScope.maybeOf(context)?.activity(),
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: field.$3),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(_error!, key: Keys.changePasscodeError),
            ),
          FilledButton(
            key: Keys.changePasscodeSubmit,
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Changing…' : 'Change passcode'),
          ),
        ],
      ),
    ),
  );
}
