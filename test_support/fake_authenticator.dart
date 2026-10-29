import 'package:quietake/auth/authenticator.dart';

class FakeAuthenticator implements Authenticator {
  FakeAuthenticator({this.isAvailable = true, this.answer = true});

  bool isAvailable;
  bool answer;
  final reasons = <String>[];
  int cancels = 0;

  @override
  String? lastError;

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<bool> get available async => isAvailable;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return answer;
  }
}
