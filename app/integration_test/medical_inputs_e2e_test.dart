import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/field_regex_test.dart' as field_regex;
import '../test/medical_inputs_test.dart' as medical_inputs;
import '../test/medical_parsers_chaos_test.dart' as parsers_chaos;

/// The medical-entry suites, run on a real device or emulator: the same keypad
/// flows, boundaries and hostile-input cases as the widget tests, so Android and
/// iOS are held to the same cases (renderer, text engine, keyboard and locale
/// handling differ from the headless test host).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('medical inputs', medical_inputs.main);
  group('hostile input', parsers_chaos.main);
  group('field regexes', field_regex.main);
}
