import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class CoreMustNotDependOnModule extends DartLintRule {
  CoreMustNotDependOnModule() : super(code: _code);
  static const _modules = ['auth','disclosure','home','profile','emergency_card','medications','sessions','account','deletion','geofence_block'];
  static const _code = LintCode(name: 'core_must_not_depend_on_module', problemMessage: 'core package must not depend on module packages.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    if (!resolver.path.contains('/packages/core/')) return;
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      for (final mod in _modules) {
        if (uri.contains('package:$mod/')) reporter.atNode(node, _code);
      }
    });
  }
}
