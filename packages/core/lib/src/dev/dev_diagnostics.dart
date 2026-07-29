import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'dev_log_buffer.dart';

/// Export helpers for the Dev Config Logs/Report tabs. Every path that lets a
/// log leave the device first runs [redactLine]; the encrypted path adds
/// AES-256-GCM on top. Log text is never returned to the UI.
class DevDiagnostics {
  const DevDiagnostics._();

  // ── Redaction ──────────────────────────────────────────────────────────────
  // Defence-in-depth before any egress. PHI/PII/secret shapes → placeholders.
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _phone = RegExp(r'\+?\d[\d\s-]{7,}\d');
  static final _date = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');
  static final _token = RegExp(r'\b(?:eyJ[\w-]+\.[\w-]+\.[\w-]+|[A-Fa-f0-9]{24,}|Bearer\s+[\w.-]+)\b');

  static String redactLine(String line) => line
      .replaceAll(_email, '[email]')
      .replaceAll(_token, '[token]')
      .replaceAll(_phone, '[phone]')
      .replaceAll(_date, '[date]');

  static List<Map<String, String>> _redactedLogs(List<DevLogEntry> entries) => entries
      .map((e) => {
            'level': e.level,
            'msg': redactLine(e.message),
            'ts': e.ts.toUtc().toIso8601String(),
          })
      .toList();

  // ── Encrypted bundle (AES-256-GCM) — mirrors devconfig.jsx saveEncryptedLogs ──
  static Future<String> buildEncryptedBundle({
    required List<DevLogEntry> entries,
    required String envLabel,
    required String envUrl,
    required String keyHex,
  }) async {
    final payload = <String, dynamic>{
      'meta': {
        'ts': DateTime.now().toUtc().toIso8601String(),
        'env': envLabel,
        'url': envUrl,
      },
      'logs': _redactedLogs(entries),
    };

    // Match the design's key derivation: UTF-8 of the hex string, padded/sliced
    // to 32 bytes.
    final keyBytes = utf8.encode(keyHex.padRight(32, '0').substring(0, 32));
    final algo = AesGcm.with256bits();
    final secretKey = await algo.newSecretKeyFromBytes(keyBytes);
    final box = await algo.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
    );

    final bundle = {
      'v': 1,
      'alg': 'AES-256-GCM',
      'iv': base64.encode(box.nonce),
      // ciphertext ‖ tag, matching WebCrypto's appended-GCM-tag layout.
      'data': base64.encode([...box.cipherText, ...box.mac.bytes]),
      'key_hint': '${keyHex.substring(0, keyHex.length < 8 ? keyHex.length : 8)}…',
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  // ── Sentry egress — replaces the design's POST /api/dev/logs ────────────────
  /// Sends a redacted diagnostic bundle to Sentry as a single event. Returns
  /// `false` (no-op) when Sentry has no DSN configured — the capture yields an
  /// empty id.
  static Future<bool> sendToSentry({
    required List<DevLogEntry> entries,
    required String envLabel,
    required String envUrl,
  }) async {
    final logs = _redactedLogs(entries);
    final id = await Sentry.captureMessage(
      '[DevConfig] diagnostic bundle · $envLabel',
      level: SentryLevel.info,
      withScope: (scope) {
        scope.setContexts('dev_diagnostics', {
          'env': envLabel,
          'url': envUrl,
          'total': entries.length,
          'errors': entries.where((e) => e.level == 'error').length,
          // Cap the payload; Sentry truncates large contexts anyway.
          'recent': logs.length > 100 ? logs.sublist(logs.length - 100) : logs,
        });
      },
    );
    return id != SentryId.empty();
  }

  // ── Bug report text — mirrors devconfig.jsx copyReport ──────────────────────
  static String buildBugReport({
    required String title,
    required String steps,
    required String severity,
    required String envLabel,
    required String envUrl,
    required List<DevLogEntry> entries,
    required String viewport,
  }) {
    final recent = entries.length > 20 ? entries.sublist(entries.length - 20) : entries;
    return [
      '# Bug Report — Balsm Patient App',
      'Date:     ${DateTime.now().toUtc().toIso8601String()}',
      'Env:      $envLabel ($envUrl)',
      'Severity: $severity',
      'Title:    ${title.isEmpty ? '(untitled)' : title}',
      '',
      '## Steps to reproduce',
      steps.isEmpty ? '(none)' : steps,
      '',
      '## Last 20 log entries (redacted)',
      ...recent.map((e) => '[${e.level.toUpperCase().padRight(5)}] ${redactLine(e.message)}'),
      '',
      '## Context',
      'Viewport: $viewport',
    ].join('\n');
  }
}
