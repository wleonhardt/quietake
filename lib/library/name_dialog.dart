import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';

Future<void> editLibraryName(
  BuildContext context, {
  required String title,
  String initial = '',
  required Future<void> Function(String) save,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _NameDialog(title: title, initial: initial, save: save),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.save,
  });
  final String title;
  final String initial;
  final Future<void> Function(String) save;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(_controller.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is FormatException
              ? e.message
              : context.l10n.librarySaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: TextField(
        key: Keys.libraryName,
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(
          labelText: context.l10n.libraryNameLabel,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: Keys.librarySave,
          onPressed: _busy ? null : _save,
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}

Future<void> updateLibrary(
  BuildContext context,
  Future<void> Function() update,
) async {
  try {
    await update();
  } on FormatException catch (e) {
    // The catalog explains stale or invalid edits; a generic retry would loop.
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.libraryUpdateFailed)));
    }
  }
}
