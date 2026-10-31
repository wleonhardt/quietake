import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration tests otherwise default to Timeout.none. Keep a per-case deadline
/// inside Flutter; tool/e2e.sh separately bounds builds, loading and teardown.
IntegrationTestWidgetsFlutterBinding initializeIntegrationBinding() =>
    IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      ..defaultTestTimeout = const Timeout(Duration(minutes: 2));
