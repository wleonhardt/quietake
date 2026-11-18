import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';

/// Where a saved recovery key is typed. Hidden by default; when shown it
/// grows to several lines so the 21 words can be read back (decision 041).
class RecoveryKeyField extends StatefulWidget {
  const RecoveryKeyField({
    super.key,
    required this.fieldKey,
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<RecoveryKeyField> createState() => _RecoveryKeyFieldState();
}

class _RecoveryKeyFieldState extends State<RecoveryKeyField> {
  var _shown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      obscureText: !_shown,
      minLines: 1,
      maxLines: _shown ? 4 : 1,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: l10n.recoveryKeyLabel,
        helperText: l10n.recoveryKeyFieldHelp,
        helperMaxLines: 2,
        suffixIcon: IconButton(
          key: Keys.recoveryFieldShow,
          tooltip: _shown ? l10n.recoveryKeyHide : l10n.recoveryKeyShow,
          icon: Icon(
            _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _shown = !_shown),
        ),
      ),
    );
  }
}
