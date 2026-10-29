import 'package:flutter/material.dart';

import '../brand.dart';
import '../keys.dart';
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
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: result.hasError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Could not finish interrupted backup restore. Prepared encrypted files are preserved. Check available storage, then try again.',
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          key: Keys.portableStartupRetry,
                          onPressed: () {
                            final next = RestoreTransaction(widget.store)
                                .resume();
                            setState(() {
                              _ready = next;
                            });
                          },
                          child: const Text('Retry restore'),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    },
  );
}
