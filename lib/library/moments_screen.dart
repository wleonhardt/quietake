import 'package:flutter/material.dart';

import '../gallery/gallery_screen.dart';
import '../gallery/item.dart';
import '../keys.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "November 2026" for a local year and month.
String monthLabel(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

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
    appBar: AppBar(title: const Text('Moments'), actions: const [LockButton()]),
    body: FutureBuilder<Map<DateTime, int>>(
      future: _months,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                _months = _load();
              }),
              child: const Text('Could not read captures. Retry'),
            ),
          );
        }
        final counts = snapshot.data;
        if (counts == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (counts.isEmpty) {
          return const Center(child: Text('No dated captures yet'));
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
                title: Text(monthLabel(month)),
                subtitle: Text(
                  '${counts[month]} ${counts[month] == 1 ? 'capture' : 'captures'}',
                ),
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
