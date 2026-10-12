import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/resolve_emergency_qr_token_use_case.dart';
import '../../domain/aggregates/profile_qr_payload.dart';
import '../../i18n/strings.dart';

/// Public, no-auth landing screen reached by scanning an emergency QR.
///
/// The app router's redirect guard MUST allowlist `/emergency/public/` so this
/// route is reachable without authentication.
///
/// The AES key is read from the URL fragment (`#k=...`) on web via
/// [Uri.base.fragment]; on mobile the deeplink router forwards it as a query
/// parameter / route extra (`key`). The fragment is never sent to the server.
/// The scanned token plus the AES key that decrypts it.
///
/// A value type, so Riverpod's family cache keys on the pair rather than on
/// object identity — the same scan re-resolves to the same request.
@immutable
class EmergencyQrRequest {
  const EmergencyQrRequest({required this.tokenId, required this.keyBase64Url});

  final String tokenId;
  final String keyBase64Url;

  @override
  bool operator ==(Object other) =>
      other is EmergencyQrRequest && other.tokenId == tokenId && other.keyBase64Url == keyBase64Url;

  @override
  int get hashCode => Object.hash(tokenId, keyBase64Url);
}

/// Resolves one scanned profile QR.
///
/// autoDispose: the decrypted payload is somebody's identity (PHI) on a
/// public, unauthenticated screen. It must not outlive the route that shows
/// it, and the next scan must hit the network rather than a warm cache.
final emergencyQrSnapshotProvider = FutureProvider.autoDispose.family<AppResult<ResolvedProfileQr>, EmergencyQrRequest>(
  (ref, request) => ref.watch(resolveEmergencyQrTokenUseCaseProvider).call(
        tokenId: request.tokenId,
        keyBase64Url: request.keyBase64Url,
      ),
);

class PublicEmergencyResolveScreen extends ConsumerWidget {
  const PublicEmergencyResolveScreen({
    super.key,
    required this.tokenId,
    this.keyOverride,
  });

  final String tokenId;

  /// Optional explicit key (mobile deeplink path). When null, the key is read
  /// from the current URL fragment (web).
  final String? keyOverride;

  String _readFragmentKey() {
    final override = keyOverride;
    if (override != null && override.isNotEmpty) return override;
    // Web: parse `k=` out of the URL fragment.
    if (kIsWeb) {
      final fragment = Uri.base.fragment; // e.g. "k=ABC123"
      for (final part in fragment.split('&')) {
        if (part.startsWith('k=')) return part.substring(2);
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The request is derived from the route, so watching it is stable across
    // rebuilds — which is what the initState-cached Future was working around.
    final request = EmergencyQrRequest(tokenId: tokenId, keyBase64Url: _readFragmentKey());
    final result = ref.watch(emergencyQrSnapshotProvider(request));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Emergency Card'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: result.when(
          loading: () => const BalsmLoadingIndicator(),
          // A thrown error is still "card unavailable" to a bystander; the
          // reason belongs in telemetry, not on a stranger's screen.
          error: (_, __) => _UnavailableView(message: emergencyCardStrings.current.unavailable),
          data: (value) => value.fold(
            (resolved) => resolved.payload == null ? const _LegacyView() : _ResolvedView(payload: resolved.payload!),
            (failure) => _UnavailableView(message: failure.message),
          ),
        ),
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_outlined, size: 56, color: BalsmColors.ink400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: BalsmColors.fg1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This emergency QR is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BalsmColors.fg2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedView extends StatelessWidget {
  const _ResolvedView({required this.payload});
  final ProfileQrPayload payload;

  @override
  Widget build(BuildContext context) {
    // Identity-only payload (spec v2.0 schema v1). Print-friendly + RTL-aware.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Balsm Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        if (payload.name != null && payload.name!.isNotEmpty) ...[
          const _Label('Name'),
          const SizedBox(height: 6),
          Text(
            payload.name!,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: BalsmColors.fg1),
          ),
          const SizedBox(height: 24),
        ],
        if (payload.dateOfBirth != null) ...[
          const _Label('Date of birth'),
          const SizedBox(height: 6),
          Text(payload.dateOfBirth!, style: const TextStyle(fontSize: 18, color: BalsmColors.fg1)),
          const SizedBox(height: 24),
        ],
        if (payload.gender != null) ...[
          const _Label('Gender'),
          const SizedBox(height: 6),
          Text(payload.gender!, style: const TextStyle(fontSize: 18, color: BalsmColors.fg1)),
        ],
      ],
    );
  }
}

/// A pre-v2.0 ciphertext decrypted, but carries no versioned payload: show a
/// refresh hint, never guess at its contents.
class _LegacyView extends StatelessWidget {
  const _LegacyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_outlined, size: 56, color: BalsmColors.ink400),
            SizedBox(height: 16),
            Text(
              'This code needs a refresh',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: BalsmColors.fg1),
            ),
            SizedBox(height: 8),
            Text(
              'Ask the owner to open their Balsm app once — the code updates itself.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BalsmColors.fg2),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: BalsmColors.fg3,
          letterSpacing: 0.4,
        ),
      );
}
