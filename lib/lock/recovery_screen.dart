import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../brand.dart';
import '../form_body.dart';

/// Shows the recovery key once. The key stays on screen and selectable but
/// never goes to the system clipboard (decision 038); Done is the only way out
/// so it cannot be skipped by accident.
///
/// The key is shown as 21 words, with the base64 text one tap away; both are
/// the same key (decision 041). The words are one line of text that wraps,
/// because a hidden entry field drops line breaks from pasted text.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.recoveryWords,
    required this.recoveryKey,
    required this.fingerprint,
    required this.onDone,
  });

  final String recoveryWords;
  final String recoveryKey;
  final String fingerprint;
  final VoidCallback onDone;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  var _asText = false;

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
              _asText ? widget.recoveryKey : widget.recoveryWords,
              key: Keys.recoveryKeyText,
              style: recoveryKeyStyle(18),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: Keys.recoveryShowText,
                onPressed: () => setState(() => _asText = !_asText),
                child: Text(
                  _asText ? l10n.recoveryShowWords : l10n.recoveryShowText,
                ),
              ),
            ),
            Text(l10n.recoveryFormsNote),
            const SizedBox(height: 16),
            Text(
              l10n.recoveryFingerprint(widget.fingerprint),
              key: Keys.recoveryFingerprint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(l10n.recoveryFingerprintNote),
            const SizedBox(height: 24),
            FilledButton(
              key: Keys.recoveryDone,
              onPressed: widget.onDone,
              child: Text(l10n.recoverySaved),
            ),
          ],
        ),
      ),
    );
  }
}
