import 'package:flutter/material.dart';

import '../keys.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Keys.backupScreen,
    appBar: AppBar(
      title: const Text('Check backup'),
      actions: const [LockButton()],
    ),
    body: ListenableBuilder(
      listenable: session.sync,
      builder: (context, _) {
        final sync = session.sync;
        final report = sync.lastVerification;
        return FormBody(
          children: [
            const Text(
              'Checks every encrypted file in your saved NAS backup using this vault’s key. Large libraries need time, data and temporary space. This check does not change originals.',
            ),
            const SizedBox(height: 20),
            if (sync.isVerifying) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(sync.verificationResult, key: Keys.backupResult),
            ),
            const SizedBox(height: 16),
            if (sync.isVerifying || sync.isVerificationQueued)
              OutlinedButton.icon(
                key: Keys.backupCancel,
                onPressed: sync.cancelVerification,
                icon: const Icon(Icons.close),
                label: Text(
                  sync.isVerifying ? 'Cancel check' : 'Cancel queued check',
                ),
              )
            else
              FilledButton.icon(
                key: Keys.backupVerify,
                onPressed: sync.verify,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Check saved backup'),
              ),
            if (report != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Checked ${MaterialLocalizations.of(context).formatMediumDate(report.checkedAt.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(report.checkedAt.toLocal()))} · ${sync.verificationCurrent ? 'Nothing changed since' : 'Changed since; check again'}',
                  key: Keys.backupTime,
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Keep your recovery key separately. A successful check does not test the copy of the key you saved elsewhere.',
            ),
            const SizedBox(height: 12),
            const Text(
              'You can leave this screen while checking. Capture uploads wait for the check to finish. Checks stop if the app process closes.',
            ),
          ],
        );
      },
    ),
  );
}
