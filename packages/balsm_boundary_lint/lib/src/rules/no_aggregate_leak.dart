import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoAggregateLeak extends DartLintRule {
  NoAggregateLeak() : super(code: _code);
  static const _code = LintCode(name: 'no_aggregate_leak', problemMessage: 'Presentation must not import domain aggregates directly. Use a read-model / view-model instead.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    // Only the presentation (UI) layer is forbidden from touching aggregates
    // directly — application/ and infrastructure/ legitimately operate on them.
    if (!resolver.path.contains('/presentation/')) return;
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      if (uri.contains('/domain/aggregates/')) reporter.atNode(node, _code);
    });
  }
}
