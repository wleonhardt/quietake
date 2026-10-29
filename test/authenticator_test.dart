import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quietake/auth/authenticator.dart';

class _NativeAuth extends Fake implements LocalAuthentication {
  final outcomes = <Object>[];
  int calls = 0;
  int stops = 0;
  bool supported = true;
  bool enrolled = true;
  bool probeFails = false;
  @override
  Future<bool> isDeviceSupported() async => supported;
  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (probeFails) throw PlatformException(code: 'not_available');
    return enrolled ? [BiometricType.fingerprint] : [];
  }

  @override
  Future<bool> authenticate({
    required localizedReason,
    authMessages = const [],
    biometricOnly = false,
    sensitiveTransaction = true,
    persistAcrossBackgrounding = false,
  }) async {
    final outcome = outcomes[calls++];
    if (outcome is bool) return outcome;
    throw outcome;
  }

  @override
  Future<bool> stopAuthentication() async {
    stops++;
    return true;
  }
}

void main() {
  for (final mode in [
    'supported',
    'unsupported',
    'unenrolled',
    'probe-failure',
  ]) {
    test(
      'biometric availability $mode keeps passcode fallback usable',
      () async {
        final native = _NativeAuth()
          ..supported = mode != 'unsupported'
          ..enrolled = mode != 'unenrolled'
          ..probeFails = mode == 'probe-failure';
        expect(
          await LocalAuthenticator(auth: native).available,
          mode == 'supported',
        );
        expect(native.calls, 0);
      },
    );
  }

  test(
    'a stale native prompt is stopped and retried using current error API',
    () async {
      final native = _NativeAuth()
        ..outcomes.addAll([
          const LocalAuthException(code: LocalAuthExceptionCode.authInProgress),
          true,
        ]);
      final auth = LocalAuthenticator(auth: native);
      expect(await auth.authenticate('Unlock'), isTrue);
      expect(native.stops, 1);
      expect(native.calls, 2);
      expect(auth.lastError, isNull);
    },
  );

  for (final code in [
    LocalAuthExceptionCode.userCanceled,
    LocalAuthExceptionCode.systemCanceled,
  ]) {
    test('$code is a cancellation, not an error', () async {
      final native = _NativeAuth()
        ..outcomes.add(LocalAuthException(code: code));
      final auth = LocalAuthenticator(auth: native);
      expect(await auth.authenticate('Unlock'), isFalse);
      expect(auth.lastError, isNull);
    });
  }
}
