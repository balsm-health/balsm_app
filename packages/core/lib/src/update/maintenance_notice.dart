import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A maintenance announcement read from a brand's release manifest
/// (`/version/<brand>.json`, see `docs/app-update.md`):
///
/// ```json
/// "maintenance": { "mode": "readonly", "message": "…", "ends_at": "2026-11-21T02:00:00Z" }
/// ```
///
/// The manifest is served from the web host, not the API server, so the
/// announcement still reaches the app when the API is down — the case
/// maintenance most needs to explain.
@immutable
class MaintenanceNotice {
  const MaintenanceNotice({required this.mode, this.message, this.endsAt});

  /// Wire value as written: `off`, `readonly` or `block`. Anything else is
  /// left for the reader to treat as unknown.
  final String mode;

  /// Admin message; null means "use the default copy".
  final String? message;

  /// Announced end, UTC; null means "not announced".
  final DateTime? endsAt;

  static const off = MaintenanceNotice(mode: 'off');
}

/// Reads the `maintenance` block of a manifest. A manifest without one says
/// [MaintenanceNotice.off]. Null when [manifest] is not a JSON object or the
/// block is malformed: a broken file must never be read as an announcement.
MaintenanceNotice? parseMaintenanceNotice(String manifest) {
  final Object? root;
  try {
    root = jsonDecode(manifest);
  } catch (_) {
    return null;
  }
  if (root is! Map<String, dynamic>) return null;
  final block = root['maintenance'];
  if (block == null) return MaintenanceNotice.off;
  if (block is! Map<String, dynamic>) return null;
  final mode = block['mode'];
  if (mode is! String) return null;
  final message = block['message'];
  final endsAt = block['ends_at'];
  return MaintenanceNotice(
    mode: mode,
    message: message is String && message.trim().isNotEmpty ? message : null,
    endsAt: endsAt is String ? DateTime.tryParse(endsAt)?.toUtc() : null,
  );
}

/// Fetches a brand's manifest for its maintenance block.
///
/// Unlike the update check it never answers from a cached copy: a block
/// remembered from an old download would lock the app after maintenance
/// ended. Any failure returns null, which the caller treats as "unknown".
class ManifestMaintenanceSource {
  ManifestMaintenanceSource({required String url, Dio? dio})
      : _url = url,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              responseType: ResponseType.plain,
            ));

  final String _url;
  final Dio _dio;

  Future<MaintenanceNotice?> read() async {
    try {
      final body = (await _dio.get<String>(_url)).data;
      return body == null ? null : parseMaintenanceNotice(body);
    } catch (_) {
      return null;
    }
  }
}
