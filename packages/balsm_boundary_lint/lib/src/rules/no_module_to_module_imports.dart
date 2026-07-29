import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoModuleToModuleImports extends DartLintRule {
  NoModuleToModuleImports() : super(code: _code);

  static const _modules = [
    'auth',
    'disclosure',
    'home',
    'profile',
    'emergency_card',
    'medications',
    'sessions',
    'account',
    'deletion',
    'geofence_block'
  ];
  static const _code = LintCode(
      name: 'no_module_to_module_imports',
      problemMessage:
          'Modules must not import other modules directly. Use core event bus or read-repository interfaces.');

  /// Package name of the file under test — feature modules live in `modules/`.
  static String _pkgOf(String path) {
    const root = '/modules/';
    final i = path.indexOf(root);
    return i < 0 ? '' : path.substring(i + root.length).split('/').first;
  }

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue ?? '';
      final currentPkg = _pkgOf(resolver.path);
      for (final mod in _modules) {
        if (currentPkg != mod && _modules.contains(currentPkg) && uri.contains('package:$mod/')) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}
