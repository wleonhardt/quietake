import 'package:integration_test/integration_test_driver.dart';

/// Integration driver. Profile benchmarks must use tool/bench.sh so a stale
/// package ID cannot make Flutter's cleanup uninstall the original app.
Future<void> main() => integrationDriver();
