import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class ModuleBarrelExposesOnlyPublicApi extends DartLintRule {
  ModuleBarrelExposesOnlyPublicApi() : super(code: _code);
  static const _code = LintCode(name: 'module_barrel_exposes_only_public_api', problemMessage: 'Module barrel may only export application/, presentation/routes.dart, domain/repositories/read_*.dart, domain/events/.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    final path = resolver.path;
    // Only check the barrel file (packages/<mod>/lib/<mod>.dart).
    final barrelPattern = RegExp(r'packages/\w+/lib/\w+\.dart$');
    if (!barrelPattern.hasMatch(path)) return;
    context.registry.addExportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      final allowed = uri.contains('application/') || uri.contains('presentation/routes') || uri.contains('domain/repositories/read_') || uri.contains('domain/events/');
      if (!allowed && uri.startsWith('src/')) reporter.atNode(node, _code);
    });
  }
}
