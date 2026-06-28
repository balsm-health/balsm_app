// @dart=3.6
// ignore_for_file: type=lint
// build_runner >=2.4.16
import 'dart:io' as _io;
import 'package:build_runner/src/build_plan/builder_factories.dart'
    as _build_runner;
import 'package:build_runner/src/bootstrap/processes.dart' as _build_runner;
import 'package:drift_dev/integrations/build.dart' as _i1;
import 'package:source_gen/builder.dart' as _i2;

final _builderFactories = _build_runner.BuilderFactories(
  {
    'drift_dev:analyzer': [_i1.discover, _i1.analyzer],
    'drift_dev:drift_dev': [_i1.discover, _i1.analyzer, _i1.driftBuilder],
    'drift_dev:modular': [_i1.modular],
    'drift_dev:not_shared': [_i1.driftBuilderNotShared],
    'drift_dev:preparing_builder': [_i1.preparingBuilder],
    'source_gen:combining_builder': [_i2.combiningBuilder],
  },
  postProcessBuilderFactories: {
    'drift_dev:cleanup': _i1.driftCleanup,
    'source_gen:part_cleanup': _i2.partCleanup,
  },
);
void main(List<String> args) async {
  _io.exitCode = await _build_runner.ChildProcess.run(
    args,
    _builderFactories,
  )!;
}
