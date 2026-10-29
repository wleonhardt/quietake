import 'package:flutter/material.dart';

import '../keys.dart';
import 'privacy_controller.dart';

class PrivacyScope extends InheritedNotifier<PrivacyController> {
  const PrivacyScope({
    super.key,
    required PrivacyController controller,
    required super.child,
  }) : super(notifier: controller);

  static PrivacyController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrivacyScope>()?.notifier;
}

class LockButton extends StatelessWidget {
  const LockButton({super.key});
  @override
  Widget build(BuildContext context) {
    final privacy = PrivacyScope.maybeOf(context);
    if (privacy == null || !privacy.enabled) return const SizedBox.shrink();
    return IconButton(
      key: Keys.lockNow,
      tooltip: 'Lock now',
      onPressed: privacy.lock,
      icon: const Icon(Icons.lock_outline),
    );
  }
}
