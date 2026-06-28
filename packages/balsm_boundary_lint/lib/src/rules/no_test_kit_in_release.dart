import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoTestKitInRelease extends DartLintRule {
  NoTestKitInRelease() : super(code: _code);
  static const _code = LintCode(name: 'no_test_kit_in_release', problemMessage: 'test_kit imports are blocked in non-dev builds.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
    if (flavor == 'dev') return;
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      if (uri.contains('test_kit')) reporter.atNode(node, _code);
    });
  }
}
