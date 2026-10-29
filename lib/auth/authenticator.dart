import 'package:local_auth/local_auth.dart';

/// Device biometric prompt. `LocalAuthenticator` wraps local_auth;
/// `FakeAuthenticator` (test_support) scripts the answer.
abstract interface class Authenticator {
  Future<bool> get available;

  /// True when the user passed the prompt. False on cancel or failure;
  /// [lastError] carries the reason when it was a failure, null on cancel.
  Future<bool> authenticate(String reason);

  String? get lastError;

  /// Dismisses a pending prompt, e.g. when the app goes to the background.
  Future<void> cancel();
}

class LocalAuthenticator implements Authenticator {
  LocalAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  String? lastError;

  @override
  Future<bool> get available async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    lastError = null;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _auth.authenticate(
          localizedReason: reason,
          biometricOnly: true,
        );
      } on LocalAuthException catch (e) {
        // A prompt left open when the activity went away (back out of the
        // app mid-prompt) makes the plugin refuse the next one: clear and retry.
        if (e.code == LocalAuthExceptionCode.authInProgress && attempt == 0) {
          await cancel();
          continue;
        }
        if (e.code == LocalAuthExceptionCode.userCanceled ||
            e.code == LocalAuthExceptionCode.systemCanceled) {
          return false;
        }
        lastError = 'Could not authenticate. Try again or use your passcode.';
        return false;
      } catch (_) {
        // Plugin internals are not user copy.
        lastError = 'Could not authenticate. Try again or use your passcode.';
        return false;
      }
    }
    return false;
  }

  @override
  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
