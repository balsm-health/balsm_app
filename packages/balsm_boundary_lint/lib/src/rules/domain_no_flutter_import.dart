import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class DomainNoFlutterImport extends DartLintRule {
  DomainNoFlutterImport() : super(code: _code);
  static const _code = LintCode(name: 'domain_no_flutter_import', problemMessage: 'Domain layer must not import flutter packages. Keep domain pure Dart.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    if (!resolver.path.contains('/src/domain/')) return;
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      if (uri.startsWith('package:flutter/')) reporter.atNode(node, _code);
    });
  }
}
