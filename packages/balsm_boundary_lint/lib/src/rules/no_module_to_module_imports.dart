import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoModuleToModuleImports extends DartLintRule {
  NoModuleToModuleImports() : super(code: _code);

  static const _modules = ['auth','disclosure','home','profile','emergency_card','medications','sessions','account','deletion','geofence_block'];
  static const _code = LintCode(name: 'no_module_to_module_imports', problemMessage: 'Modules must not import other modules directly. Use core event bus or read-repository interfaces.');

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      final currentPkg = resolver.path.split('/packages/').elementAtOrNull(1)?.split('/').first ?? '';
      for (final mod in _modules) {
        if (currentPkg != mod && _modules.contains(currentPkg) && uri.contains('package:$mod/')) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}
