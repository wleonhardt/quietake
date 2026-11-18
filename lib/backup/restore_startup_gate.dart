import 'package:flutter/material.dart';

import '../brand.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/screen_privacy.dart';
import '../vault/master_key_store.dart';
import 'restore_transaction.dart';

/// An interrupted restore must not strand startup on an unhandled exception or
/// expose a partially adopted vault. Retry preserves its prepared encrypted data.
class RestoreStartupGate extends StatefulWidget {
  const RestoreStartupGate({
    super.key,
    required this.store,
    required this.child,
  });
  final MasterKeyStore store;
  final Widget child;
  @override
  State<RestoreStartupGate> createState() => _RestoreStartupGateState();
}

class _RestoreStartupGateState extends State<RestoreStartupGate> {
  late Future<bool> _ready = RestoreTransaction(widget.store).resume();

  /// Discard is offered only once a retry has failed too.
  var _retried = false;

  Future<void> _discard(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreGateDiscardTitle),
        content: Text(l10n.restoreGateDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: Keys.portableStartupDiscardConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restoreGateDiscardConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final transaction = RestoreTransaction(widget.store);
    setState(() {
      _ready = transaction.discard().then((_) => transaction.resume());
    });
  }
  late final _cover = ScreenPrivacy((_) {});
  @override
  void initState() {
    super.initState();
    // The cover is best effort during the gate; a native failure must not
    // become an uncaught startup error.
    _cover.start().catchError((Object _) {});
    _ready.then<void>((_) => _cover.dispose(), onError: (Object _) {});
  }

  @override
  void dispose() {
    _cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _ready,
    builder: (context, result) {
      if (result.connectionState == ConnectionState.done && !result.hasError) {
        return widget.child;
      }
      return MaterialApp(
        theme: quietakeTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: result.hasError
                  ? Builder(
                      // Below the MaterialApp so the strings see its locale.
                      builder: (context) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(context.l10n.restoreGateFailed),
                          const SizedBox(height: 20),
                          FilledButton(
                            key: Keys.portableStartupRetry,
                            onPressed: () {
                              final next = RestoreTransaction(widget.store)
                                  .resume();
                              setState(() {
                                _ready = next;
                                _retried = true;
                              });
                            },
                            child: Text(context.l10n.restoreGateRetry),
                          ),
                          if (_retried) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              key: Keys.portableStartupDiscard,
                              onPressed: () => _discard(context),
                              child: Text(context.l10n.restoreGateDiscard),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    },
  );
}
