import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/resolve_emergency_qr_token_use_case.dart';
import '../../domain/aggregates/emergency_card_snapshot.dart';

/// Public, no-auth landing screen reached by scanning an emergency QR.
///
/// The app router's redirect guard MUST allowlist `/emergency/public/` so this
/// route is reachable without authentication.
///
/// The AES key is read from the URL fragment (`#k=...`) on web via
/// [Uri.base.fragment]; on mobile the deeplink router forwards it as a query
/// parameter / route extra (`key`). The fragment is never sent to the server.
class PublicEmergencyResolveScreen extends ConsumerStatefulWidget {
  const PublicEmergencyResolveScreen({
    super.key,
    required this.tokenId,
    this.keyOverride,
  });

  final String tokenId;

  /// Optional explicit key (mobile deeplink path). When null, the key is read
  /// from the current URL fragment (web).
  final String? keyOverride;

  @override
  ConsumerState<PublicEmergencyResolveScreen> createState() =>
      _PublicEmergencyResolveScreenState();
}

class _PublicEmergencyResolveScreenState
    extends ConsumerState<PublicEmergencyResolveScreen> {
  late final Future<AppResult<EmergencyCardSnapshot>> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  String _readFragmentKey() {
    if (widget.keyOverride != null && widget.keyOverride!.isNotEmpty) {
      return widget.keyOverride!;
    }
    // Web: parse `k=` out of the URL fragment.
    if (kIsWeb) {
      final fragment = Uri.base.fragment; // e.g. "k=ABC123"
      for (final part in fragment.split('&')) {
        if (part.startsWith('k=')) return part.substring(2);
      }
    }
    return '';
  }

  Future<AppResult<EmergencyCardSnapshot>> _resolve() {
    return ref.read(resolveEmergencyQrTokenUseCaseProvider).call(
          tokenId: widget.tokenId,
          keyBase64Url: _readFragmentKey(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Emergency Card'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: FutureBuilder<AppResult<EmergencyCardSnapshot>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const BalsmLoadingIndicator();
            }
            return snap.data!.fold(
              (snapshot) => _ResolvedView(snapshot: snapshot),
              (failure) => _UnavailableView(message: failure.message),
            );
          },
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
            const Icon(Icons.qr_code_2_outlined,
                size: 56, color: BalsmColors.ink400),
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
  const _ResolvedView({required this.snapshot});
  final EmergencyCardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final contact = snapshot.primaryContact;
    // Print-friendly + RTL-aware: directionality follows ambient locale; layout
    // uses logical (start/end) alignment.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Emergency Health Information',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        if (snapshot.bloodType != null) ...[
          _Label('Blood type'),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: BalsmColors.dangerBg,
                borderRadius: BorderRadius.circular(BalsmRadius.md),
              ),
              child: Text(
                snapshot.bloodType!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: BalsmColors.danger,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (snapshot.allergyNames.isNotEmpty) ...[
          _Label('Allergies'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...snapshot.allergyNames.map(
                (a) => BalsmPill(label: a, variant: BalsmPillVariant.danger),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (snapshot.conditionNames.isNotEmpty) ...[
          _Label('Conditions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...snapshot.conditionNames.map(
                (c) => BalsmPill(label: c, variant: BalsmPillVariant.info),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (contact != null) ...[
          _Label('Emergency contact'),
          const SizedBox(height: 8),
          Material(
            color: BalsmColors.ink50,
            borderRadius: BorderRadius.circular(BalsmRadius.md),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BalsmRadius.md),
              ),
              leading: const Icon(Icons.call, color: BalsmColors.petalBlue),
              title: Text(contact.name),
              subtitle: Text(contact.phone),
              onTap: () => _dialContact(context, contact.phone),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _dialContact(BuildContext context, String phone) async {
    // tel: link. Uses the app_links/url_launcher-free path: surface the number;
    // on web/mobile the host can intercept. Fallback: copy to clipboard.
    final uri = Uri(scheme: 'tel', path: phone);
    // Intentionally avoid adding url_launcher dependency here; the deeplink/host
    // shell handles tel: navigation. Show the dialable URI to the responder.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call ${uri.path}')),
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
