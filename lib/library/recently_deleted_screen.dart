import 'dart:io';

import 'package:flutter/material.dart';

import '../gallery/item.dart';
import '../keys.dart';
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
      _say('Could not restore. Please retry.');
    }
    _reload();
  }

  Future<void> _deleteNow(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete now?'),
        content: const Text(
          'This capture is permanently removed from this phone and your '
          'configured NAS. It cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Keys.recentlyDeletedConfirm,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.session.sync.delete(_file(name));
      widget.session.previews.evict(name);
    } catch (_) {
      _say('Could not finish deleting. Please retry.');
    }
    _reload();
  }

  void _say(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Keys.recentlyDeletedScreen,
    appBar: AppBar(
      title: const Text('Recently deleted'),
      actions: const [LockButton()],
    ),
    body: FutureBuilder<Map<String, DateTime>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('Could not read deleted captures. Retry'),
            ),
          );
        }
        final items = snapshot.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(
            key: Keys.recentlyDeletedEmpty,
            child: Text('Nothing recently deleted'),
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
                'Deleted captures stay encrypted on this phone for '
                '${Vault.trashKeep.inDays} days, then are removed for good.',
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
      subtitle: Text('$left ${left == 1 ? 'day' : 'days'} left'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Keys.recentlyDeletedRestore(name),
            tooltip: 'Restore',
            icon: const Icon(Icons.restore),
            onPressed: () => _restore(name),
          ),
          IconButton(
            key: Keys.recentlyDeletedNow(name),
            tooltip: 'Delete now',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => _deleteNow(name),
          ),
        ],
      ),
    );
  }
}
