import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../brand.dart';
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
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.recoveryKeyLabel),
          automaticallyImplyLeading: false,
        ),
        body: FormBody(
          children: [
            Text(l10n.recoveryKeyIntro),
            const SizedBox(height: 24),
            SelectableText(
              recoveryKey,
              key: Keys.recoveryKeyText,
              style: recoveryKeyStyle(18),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.recoveryFingerprint(fingerprint),
              key: Keys.recoveryFingerprint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(l10n.recoveryFingerprintNote),
            const SizedBox(height: 24),
            FilledButton(
              key: Keys.recoveryDone,
              onPressed: onDone,
              child: Text(l10n.recoverySaved),
            ),
          ],
        ),
      ),
    );
  }
}
