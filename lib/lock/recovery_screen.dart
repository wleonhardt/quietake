import 'package:flutter/material.dart';

import '../keys.dart';
import '../form_body.dart';

/// Shows the recovery key once. The key stays on screen and selectable but
/// never goes to the system clipboard (decision 038); Done is the only way out
/// so it cannot be skipped by accident.
class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({
    super.key,
    required this.recoveryKey,
    required this.fingerprint,
    required this.onDone,
  });

  final String recoveryKey;
  final String fingerprint;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recovery key'),
          automaticallyImplyLeading: false,
        ),
        body: FormBody(
          children: [
            const Text(
              'Keep this key in your password manager, separately from your '
              'encrypted files. You need both to recover your captures if you '
              'forget the passcode or lose this device. A NAS backup passphrase '
              'is another recovery option only if you have enabled it.',
            ),
            const SizedBox(height: 24),
            SelectableText(
              recoveryKey,
              key: Keys.recoveryKeyText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Fingerprint $fingerprint',
              key: Keys.recoveryFingerprint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Text(
              'Save the fingerprint with the key. A new phone shows it so you '
              'can check the key you typed.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: Keys.recoveryDone,
              onPressed: onDone,
              child: const Text('I saved it'),
            ),
          ],
        ),
      ),
    );
  }
}
