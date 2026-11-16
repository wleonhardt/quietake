import 'dart:async';

import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../gallery/item.dart';
import 'cast_backend.dart';
import 'cast_controller.dart';

/// Keep the receiver route discoverable until the connection attempt finishes.
Future<void> _connectCastDevice(
  BuildContext context,
  CastController cast,
  VaultItem? item,
) async {
  if (!await cast.startDiscovery()) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.castSearchFailed)));
    }
    return;
  }
  try {
    if (!context.mounted) return;
    final device = await showModalBottomSheet<CastDevice>(
      context: context,
      builder: (_) => _DevicePicker(cast: cast),
    );
    if (device != null && context.mounted) {
      await cast.start(device, item);
      if (item == null && cast.isCasting && context.mounted) {
        // From the Library nothing is showing yet; say what happens next.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.castConnected(device.name))),
        );
      }
    }
  } finally {
    await cast.stopDiscovery();
  }
}

class _DevicePicker extends StatefulWidget {
  const _DevicePicker({required this.cast});

  final CastController cast;

  @override
  State<_DevicePicker> createState() => _DevicePickerState();
}

class _DevicePickerState extends State<_DevicePicker> {
  static const _patience = Duration(seconds: 10);
  Timer? _timer;
  bool _waitedLong = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _waitedLong = false;
    _timer = Timer(_patience, () {
      if (mounted) setState(() => _waitedLong = true);
    });
  }

  Future<void> _retry() async {
    setState(_arm);
    await widget.cast.stopDiscovery();
    await widget.cast.startDiscovery();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: Keys.castSheet,
      child: StreamBuilder(
        stream: widget.cast.devices,
        builder: (context, snap) {
          final list = snap.data ?? const <CastDevice>[];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        context.l10n.castTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Keys.castClose,
                    tooltip: context.l10n.castClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(context.l10n.castUnencrypted),
              ),
              if (list.isEmpty && !_waitedLong)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.l10n.castLooking, key: Keys.castEmpty),
                ),
              if (list.isEmpty && _waitedLong)
                ListTile(
                  key: Keys.castEmpty,
                  leading: const Icon(Icons.tv_off_outlined),
                  title: Text(context.l10n.castNoneFound),
                  subtitle: Text(context.l10n.castSameWifi),
                  trailing: TextButton(
                    key: Keys.castRetry,
                    onPressed: _retry,
                    child: Text(context.l10n.castRetry),
                  ),
                ),
              for (var i = 0; i < list.length; i++)
                ListTile(
                  key: Keys.castDevice(i),
                  leading: const Icon(Icons.tv),
                  title: Text(list[i].name),
                  onTap: () => Navigator.of(context).pop(list[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shared cast action prevents overlapping discovery/connect requests in the UI.
class CastButton extends StatefulWidget {
  const CastButton({super.key, required this.cast, this.item});
  final CastController cast;
  final VaultItem? item;
  @override
  State<CastButton> createState() => _CastButtonState();
}

class _CastButtonState extends State<CastButton> {
  bool _picking = false;
  Future<void> _press() async {
    final cast = widget.cast;
    if (cast.isCasting || cast.isConnecting) {
      await cast.stop();
      return;
    }
    if (_picking) return;
    setState(() => _picking = true);
    try {
      await _connectCastDevice(context, cast, widget.item);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.cast,
    builder: (context, _) => IconButton(
      tooltip: widget.cast.isCasting
          ? context.l10n.castStop(widget.cast.device!.name)
          : widget.cast.isConnecting
          ? context.l10n.castCancelConnection
          : context.l10n.castToTv,
      icon: Icon(widget.cast.isCasting ? Icons.cast_connected : Icons.cast),
      color: widget.cast.isCasting
          ? Theme.of(context).colorScheme.primary
          : null,
      onPressed: _picking && !widget.cast.isConnecting ? null : _press,
    ),
  );
}
