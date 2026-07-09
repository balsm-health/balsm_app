import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class ModuleBarrelExposesOnlyPublicApi extends DartLintRule {
  ModuleBarrelExposesOnlyPublicApi() : super(code: _code);
  static const _code = LintCode(name: 'module_barrel_exposes_only_public_api', problemMessage: 'Module barrel may only export application/, infrastructure/ (DI providers), presentation/routes.dart, domain/repositories/read_*.dart, domain/events/, domain/value_objects/. Do not export screens.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    final path = resolver.path;
    // Only check a feature-module barrel (modules/<mod>/lib/<mod>.dart).
    // Scoped to modules/ so it never fires on core/libs under packages/.
    final barrelPattern = RegExp(r'modules/\w+/lib/\w+\.dart$');
    if (!barrelPattern.hasMatch(path)) return;
    context.registry.addExportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      // value_objects allowed: immutable, side-effect-free, and typed ids are
      // part of a module's public contract (they ride on exported events).
      final allowed = uri.contains('application/') || uri.contains('infrastructure/') || uri.contains('presentation/routes') || uri.contains('domain/repositories/read_') || uri.contains('domain/events/') || uri.contains('domain/value_objects/');
      if (!allowed && uri.startsWith('src/')) reporter.atNode(node, _code);
    });
  }
}
