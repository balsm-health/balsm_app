import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/entity_id.dart';

/// The active entity (facility — clinic/hospital/pharmacy) the user is
/// currently working in. Sibling of `currentUserIdProvider`.
///
/// Overridden in the app shell's `bootstrap()`; updated when the user
/// switches facility. Null when no facility is selected — entity-scoped
/// writes then throw `NoActiveEntityException` (fail-loud), reads return
/// null.
///
/// Modules read this port instead of any facility-selection state so they
/// stay decoupled from the module that owns switching.
final currentEntityIdProvider = Provider<EntityId?>(
  (ref) => null,
);
