import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoAggregateLeak extends DartLintRule {
  NoAggregateLeak() : super(code: _code);
  static const _code = LintCode(name: 'no_aggregate_leak', problemMessage: 'Aggregate classes must not be imported outside their domain/aggregates/ directory.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    if (resolver.path.contains('/domain/aggregates/')) return;
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      if (uri.contains('/domain/aggregates/')) reporter.atNode(node, _code);
    });
  }
}
