import 'dart:math';

import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../brand.dart';
import '../form_body.dart';
import '../vault/recovery_words.dart';

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
    this.confirm = false,
  });

  final String recoveryWords;
  final String recoveryKey;
  final String fingerprint;
  final VoidCallback onDone;

  /// Setup asks for one word of the saved copy before Done counts
  /// (decision 042). Showing the key again from Settings does not.
  final bool confirm;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  var _asText = false;

  /// The 1-based word asked back, or null while the key is shown.
  int? _asked;
  var _wrong = false;
  final _typed = TextEditingController();

  List<String> get _words => widget.recoveryWords.split(' ');

  /// Numbered so a word can be asked back; the number stays with its word
  /// when the line wraps, and entry fields ignore the numbers.
  String get _numbered =>
      [for (final (i, word) in _words.indexed) '${i + 1}\u00a0$word']
          .join('   ');

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _saved() {
    if (!widget.confirm) return widget.onDone();
    setState(() {
      _asked = Random.secure().nextInt(_words.length) + 1;
      _wrong = false;
      _typed.clear();
    });
  }

  /// One word is enough for a paper copy; someone who saved the key in a
  /// password manager can paste all of it, in either form.
  void _check() {
    final typed = RecoveryWords.wordsOf(_typed.text);
    if ((typed.length == 1 && typed.single == _words[_asked! - 1]) ||
        typed.join(' ') == widget.recoveryWords ||
        _typed.text.replaceAll(RegExp(r'[\s-]'), '') ==
            widget.recoveryKey.replaceAll(' ', '')) {
      widget.onDone();
    } else {
      setState(() => _wrong = true);
    }
  }

  List<Widget> _confirmStep(AppLocalizations l10n) => [
    Text(l10n.recoveryConfirmBody(_asked!)),
    const SizedBox(height: 24),
    TextField(
      key: Keys.recoveryConfirmField,
      controller: _typed,
      autofocus: true,
      enableSuggestions: false,
      autocorrect: false,
      onSubmitted: (_) => _check(),
      decoration: InputDecoration(
        labelText: l10n.recoveryConfirmField(_asked!),
        error: _wrong
            ? Semantics(
                liveRegion: true,
                child: Text(
                  l10n.recoveryConfirmWrong(_asked!),
                  key: Keys.recoveryConfirmError,
                ),
              )
            : null,
      ),
    ),
    const SizedBox(height: 24),
    FilledButton(
      key: Keys.recoveryConfirmOk,
      onPressed: _check,
      child: Text(l10n.recoveryConfirmAction),
    ),
    TextButton(
      key: Keys.recoveryConfirmBack,
      onPressed: () => setState(() => _asked = null),
      child: Text(l10n.recoveryConfirmBack),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_asked != null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.recoveryConfirmTitle),
            automaticallyImplyLeading: false,
          ),
          body: FormBody(children: _confirmStep(l10n)),
        ),
      );
    }
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
              _asText ? widget.recoveryKey : _numbered,
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
              onPressed: _saved,
              child: Text(l10n.recoverySaved),
            ),
          ],
        ),
      ),
    );
  }
}
