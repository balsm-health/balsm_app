import 'package:core/core.dart';

import '../../domain/aggregates/pregnancy.dart';
import '../../domain/entities/pregnancy_item.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for pregnancies and their items, partitioned by the
/// mother's health profile (core [ProfileDataSource] scope semantics: a null
/// scope resolves the bound profile; none → reads empty, writes throw
/// [NoActiveProfileException]).
///
/// Reads leave soft-deleted rows out. [delete] and [deleteItem] are soft;
/// [clear] / [clearAll] remove rows outright (account wipe). The drift
/// implementation lives in `infrastructure/drift/`.
abstract interface class PregnanciesDataSource
    implements
        ProfileDataSource<PregnancyId, Pregnancy>,
        WatchableScopedDataSource<PregnancyId, Pregnancy, HealthProfileId> {
  /// The pregnancy being tracked, if any (newest active one).
  Future<Pregnancy?> findActive({HealthProfileId? scope});

  /// The items of [pregnancy], newest first, with their baby links.
  Future<List<PregnancyItem>> findItems(PregnancyId pregnancy, {HealthProfileId? scope});

  /// [findItems], live.
  Stream<List<PregnancyItem>> watchItems(PregnancyId pregnancy, {HealthProfileId? scope});

  /// Stores a new item and its baby links. Throws [StorageWriteException]
  /// when its pregnancy is not in the partition.
  Future<void> addItem(PregnancyItem item, {HealthProfileId? scope});

  /// Soft-deletes item [id]; false when it is not a live item of the
  /// partition.
  Future<bool> deleteItem(PregnancyItemId id, {HealthProfileId? scope});

  /// Detaches [items] from baby [babyId] (soft-deletes the links); the items
  /// stay on the pregnancy. Returns how many links were detached.
  Future<int> detachItems(HealthProfileId babyId, Iterable<PregnancyItemId> items, {HealthProfileId? scope});
}
