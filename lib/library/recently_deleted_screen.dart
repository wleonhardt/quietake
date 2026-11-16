import 'dart:io';

import 'package:flutter/material.dart';

import '../gallery/item.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';
import '../vault/vault.dart';
import 'moments_screen.dart';

/// Whole days left before [trashedAt] expires at [now], never below zero.
int daysLeft(DateTime trashedAt, DateTime now) {
  final left = Vault.trashKeep - now.difference(trashedAt);
  return left.isNegative ? 0 : (left.inHours / 24).ceil();
}

/// Lists captures hidden by Delete. It reads names and marker times only, so it
/// needs no decryption.
class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key, required this.session, this.clock});
  final Session session;
  final DateTime Function()? clock;
  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  late Future<Map<String, DateTime>> _items = _load();
  Vault get _vault => widget.session.vault;

  Future<Map<String, DateTime>> _load() => _vault.trashedAt();

  void _reload() {
    if (!mounted) return;
    setState(() {
      _items = _load();
    });
  }

  File _file(String name) => File('${_vault.dir.path}/$name');

  Future<void> _restore(String name) async {
    try {
      await _vault.restore(_file(name));
    } catch (_) {
      _say((l10n) => l10n.recentlyDeletedRestoreFailed);
    }
    _reload();
  }

  Future<void> _deleteNow(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.recentlyDeletedDeleteNowTitle),
        content: Text(context.l10n.recentlyDeletedDeleteNowBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: Keys.recentlyDeletedConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.recentlyDeletedDeleteNow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.session.sync.delete(_file(name));
      widget.session.previews.evict(name);
    } catch (_) {
      _say((l10n) => l10n.recentlyDeletedDeleteFailed);
    }
    _reload();
  }

  Future<void> _deleteAll(List<String> names) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.recentlyDeletedAllTitle),
        content: Text(context.l10n.recentlyDeletedAllBody(names.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: Keys.recentlyDeletedAllConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.recentlyDeletedAllNow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      for (final name in names) {
        await widget.session.sync.delete(_file(name));
        widget.session.previews.evict(name);
      }
    } catch (_) {
      _say((l10n) => l10n.recentlyDeletedDeleteFailed);
    }
    _reload();
  }

  void _say(String Function(AppLocalizations) text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text(context.l10n))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Keys.recentlyDeletedScreen,
    appBar: AppBar(
      title: Text(context.l10n.recentlyDeletedTitle),
      actions: const [LockButton()],
    ),
    body: FutureBuilder<Map<String, DateTime>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: Text(context.l10n.recentlyDeletedLoadFailed),
            ),
          );
        }
        final items = snapshot.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return Center(
            key: Keys.recentlyDeletedEmpty,
            child: Text(context.l10n.recentlyDeletedEmpty),
          );
        }
        final now = (widget.clock ?? DateTime.now)();
        final names = items.keys.toList()
          ..sort((a, b) => items[b]!.compareTo(items[a]!));
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.recentlyDeletedNote(Vault.trashKeep.inDays),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  key: Keys.recentlyDeletedAll,
                  onPressed: () => _deleteAll(names),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(context.l10n.recentlyDeletedAllNow),
                ),
              ),
            ),
            for (final name in names) _tile(name, items[name]!, now),
          ],
        );
      },
    ),
  );

  Widget _tile(String name, DateTime at, DateTime now) {
    final item = VaultItem(File(name));
    final taken = item.capturedAt?.toLocal();
    final left = daysLeft(at, now);
    return ListTile(
      key: Keys.recentlyDeletedItem(name),
      leading: Icon(
        item.isVideo ? Icons.videocam_outlined : Icons.photo_outlined,
      ),
      title: Text(taken == null ? name : monthLabel(taken)),
      subtitle: Text(context.l10n.recentlyDeletedDaysLeft(left)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Keys.recentlyDeletedRestore(name),
            tooltip: context.l10n.recentlyDeletedRestore,
            icon: const Icon(Icons.restore),
            onPressed: () => _restore(name),
          ),
          IconButton(
            key: Keys.recentlyDeletedNow(name),
            tooltip: context.l10n.recentlyDeletedDeleteNow,
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => _deleteNow(name),
          ),
        ],
      ),
    );
  }
}
