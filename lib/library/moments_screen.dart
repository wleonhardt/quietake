import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../gallery/gallery_screen.dart';
import '../gallery/item.dart';
import '../keys.dart';
import '../l10n/l10n.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';

/// "November 2026" for a local year and month, in the app language.
String monthLabel(BuildContext context, DateTime month) {
  final locale = Localizations.maybeLocaleOf(context)?.toString() ?? 'en';
  return DateFormat.yMMMM(locale).format(month);
}

/// Groups captures by the local month in their file name. It reads file names
/// only, so it needs no decryption and keeps no index.
class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key, required this.session});
  final Session session;
  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  late Future<Map<DateTime, int>> _months = _load();

  Future<Map<DateTime, int>> _load() async {
    final counts = <DateTime, int>{};
    for (final file in await widget.session.vault.list()) {
      final taken = VaultItem(file).capturedAt?.toLocal();
      if (taken == null) continue;
      counts.update(
        DateTime(taken.year, taken.month),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Keys.momentsScreen,
    appBar: AppBar(
      title: Text(context.l10n.tagsMoments),
      actions: const [LockButton()],
    ),
    body: FutureBuilder<Map<DateTime, int>>(
      future: _months,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                _months = _load();
              }),
              child: Text(context.l10n.momentsLoadFailed),
            ),
          );
        }
        final counts = snapshot.data;
        if (counts == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (counts.isEmpty) {
          return Center(child: Text(context.l10n.momentsEmpty));
        }
        final months = counts.keys.toList()..sort((a, b) => b.compareTo(a));
        return ListView(
          children: [
            for (final month in months)
              ListTile(
                key: Keys.momentMonth(
                  '${month.year}-${month.month.toString().padLeft(2, '0')}',
                ),
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(monthLabel(context, month)),
                subtitle: Text(context.l10n.tagsCaptureCount(counts[month]!)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GalleryScreen(
                        session: widget.session,
                        searchMode: true,
                        initialMonth: month,
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _months = _load();
                    });
                  }
                },
              ),
          ],
        );
      },
    ),
  );
}
