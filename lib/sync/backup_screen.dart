import 'package:flutter/material.dart';

import '../keys.dart';
import '../l10n/l10n.dart';
import '../form_body.dart';
import '../privacy/privacy_scope.dart';
import '../session.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      key: Keys.backupScreen,
      appBar: AppBar(
        title: Text(l10n.backupTitle),
        actions: const [LockButton()],
      ),
      body: ListenableBuilder(
        listenable: session.sync,
        builder: (context, _) {
          final sync = session.sync;
          final report = sync.lastVerification;
          return FormBody(
            children: [
              Text(l10n.backupIntro),
              const SizedBox(height: 20),
              if (sync.isVerifying) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(sync.verificationResult, key: Keys.backupResult),
              ),
              if (sync.verificationStale && !sync.isVerifying)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    sync.lastVerifiedAt == null
                        ? l10n.backupNeverChecked
                        : l10n.backupStale(
                            DateTime.now()
                                .difference(sync.lastVerifiedAt!)
                                .inDays,
                          ),
                    key: Keys.backupStale,
                  ),
                ),
              const SizedBox(height: 16),
              if (sync.isVerifying || sync.isVerificationQueued)
                OutlinedButton.icon(
                  key: Keys.backupCancel,
                  onPressed: sync.cancelVerification,
                  icon: const Icon(Icons.close),
                  label: Text(
                    sync.isVerifying
                        ? l10n.backupCancelCheck
                        : l10n.backupCancelQueued,
                  ),
                )
              else
                FilledButton.icon(
                  key: Keys.backupVerify,
                  onPressed: sync.verify,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(l10n.backupCheckSaved),
                ),
              if (report != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    l10n.backupCheckedAt(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(report.checkedAt.toLocal()),
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(report.checkedAt.toLocal()),
                      ),
                      sync.verificationCurrent
                          ? l10n.backupUnchanged
                          : l10n.backupChanged,
                    ),
                    key: Keys.backupTime,
                  ),
                ),
              const SizedBox(height: 24),
              Text(l10n.backupKeepKey),
              const SizedBox(height: 12),
              Text(l10n.backupLeaveNote),
            ],
          );
        },
      ),
    );
  }
}
