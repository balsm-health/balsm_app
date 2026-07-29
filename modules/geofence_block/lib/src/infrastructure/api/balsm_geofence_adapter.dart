import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/read_denied_countries_repository.dart';

/// SecureStorage key holding the cached deny list + fetch timestamp.
const _cacheKey = 'balsm.denied_countries_cache';

/// How long a cached deny list is considered fresh.
const _cacheTtl = Duration(hours: 24);

/// HTTP adapter implementing [ReadDeniedCountriesRepository] against the Balsm
/// backend (`GET /geofence/denied-countries`).
///
/// Behaviour:
/// - [isDenied] consults the cache first; on a miss/stale cache it fetches.
/// - Results are cached for 24h in [SecureStorageWrapper] under [_cacheKey].
/// - PHI-free: country codes are not personal health information, so they may
///   be logged and cached.
///
/// Uses the typed [GeofenceApi] from `balsm_api` for transport, matching the
/// convention used by other bounded contexts.
class BalsmGeofenceAdapter implements ReadDeniedCountriesRepository {
  BalsmGeofenceAdapter({
    required GeofenceApi api,
    required SecureStorageWrapper storage,
  })  : _api = api,
        _storage = storage;

  final GeofenceApi _api;
  final SecureStorageWrapper _storage;

  @override
  Future<bool> isDenied(String countryCode) async {
    final normalized = countryCode.trim().toUpperCase();
    if (normalized.isEmpty) return false;

    final codes = await _deniedCountryCodes();
    return codes.contains(normalized);
  }

  @override
  Stream<List<String>> watchDeniedCountryCodes() async* {
    yield await _deniedCountryCodes();
  }

  /// Returns the deny list, preferring a fresh cache and falling back to a
  /// network fetch. On network failure a stale cache (if any) is returned so
  /// that previously-known blocks remain enforced offline.
  Future<List<String>> _deniedCountryCodes() async {
    final cached = await _readCache();
    if (cached != null && cached.isFresh) {
      return cached.codes;
    }

    try {
      final codes = await _fetch();
      await _writeCache(codes);
      return codes;
    } catch (_) {
      // Network unavailable: fall back to the last known list (even if stale).
      return cached?.codes ?? const <String>[];
    }
  }

  Future<List<String>> _fetch() async {
    final res = await _api.getDeniedCountries();
    return res.deniedCodes.map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  Future<_CachedDenyList?> _readCache() async {
    final raw = await _storage.readToken(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.tryParse(json['fetched_at'] as String? ?? '');
      if (fetchedAt == null) return null;
      final codes = (json['codes'] as List? ?? const []).map((e) => e.toString()).toList(growable: false);
      return _CachedDenyList(codes: codes, fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(List<String> codes) async {
    final payload = jsonEncode({
      'codes': codes,
      'fetched_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _storage.writeToken(_cacheKey, payload);
  }
}

class _CachedDenyList {
  const _CachedDenyList({required this.codes, required this.fetchedAt});

  final List<String> codes;
  final DateTime fetchedAt;

  bool get isFresh => DateTime.now().toUtc().difference(fetchedAt.toUtc()) < _cacheTtl;
}

/// Riverpod provider exposing the geofence deny-list repository.
final deniedCountriesRepositoryProvider = Provider<ReadDeniedCountriesRepository>((ref) {
  return BalsmGeofenceAdapter(
    api: ref.watch(geofenceApiProvider),
    storage: ref.watch(secureStorageProvider),
  );
});
