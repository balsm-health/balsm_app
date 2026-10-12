import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/core_must_not_depend_on_module.dart';
import 'src/rules/domain_no_flutter_import.dart';
import 'src/rules/module_barrel_exposes_only_public_api.dart';
import 'src/rules/no_aggregate_leak.dart';
import 'src/rules/no_module_to_module_imports.dart';
import 'src/rules/no_test_kit_in_release.dart';

/// custom_lint entrypoint — registers the Balsm DDD boundary rules.
PluginBase createPlugin() => _BalsmBoundaryLint();

class _BalsmBoundaryLint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        NoModuleToModuleImports(),
        CoreMustNotDependOnModule(),
        ModuleBarrelExposesOnlyPublicApi(),
        DomainNoFlutterImport(),
        NoAggregateLeak(),
        NoTestKitInRelease(),
      ];
}
