import 'dart:async';

import 'package:emergency_card/emergency_card.dart'
    show ProfileQrPayload, ResolvedProfileQr, permanentQrStoreProvider, resolveEmergencyQrTokenUseCaseProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// A successfully scanned + decrypted profile QR.
typedef ScannedProfile = ({String jti, ProfileQrPayload payload});

/// Design `QRScanView`: live camera viewfinder with corner brackets and a
/// sweeping scan line. Recognises Balsm profile-QR URLs (`/t/{jti}#k=…`,
/// legacy `/emergency/{jti}#k=…`), resolves the ciphertext through the public
/// endpoint, and decrypts it with the key from the fragment — the identity
/// payload (PHI) stays in memory and is never logged.
class FamilyQrScanView extends ConsumerStatefulWidget {
  const FamilyQrScanView({super.key, required this.onFound, required this.onManual});

  final void Function(ScannedProfile found) onFound;
  final VoidCallback onManual;

  @override
  ConsumerState<FamilyQrScanView> createState() => _FamilyQrScanViewState();
}

class _FamilyQrScanViewState extends ConsumerState<FamilyQrScanView> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _busy = false;
  bool _found = false;
  String? _flash;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// `/t/{jti}` (spec v2.0) or legacy `/emergency/{jti}`; key in `#k=`.
  ({String jti, String key})? _parse(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final segs = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (segs.length != 2 || (segs[0] != 't' && segs[0] != 'emergency')) return null;
    String key = '';
    for (final part in uri.fragment.split('&')) {
      if (part.startsWith('k=')) key = part.substring(2);
    }
    if (key.isEmpty) return null;
    return (jti: segs[1], key: key);
  }

  void _note(String msg) {
    _flashTimer?.cancel();
    setState(() => _flash = msg);
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _found) return;
    final s = AppScope.of(context);
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final parsed = _parse(raw);
    if (parsed == null) {
      if (raw != null) _note(s.strings.common.fam_scan_invalid);
      return;
    }
    setState(() => _busy = true);
    // You cannot add yourself: your own permanent QR carries your own jti.
    final own = await ref.read(permanentQrStoreProvider).read();
    if (!mounted) return;
    if (own != null && own.jti == parsed.jti) {
      setState(() => _busy = false);
      _note(s.strings.common.fam_self_add);
      return;
    }
    final result =
        await ref.read(resolveEmergencyQrTokenUseCaseProvider).call(tokenId: parsed.jti, keyBase64Url: parsed.key);
    if (!mounted) return;
    final ResolvedProfileQr? resolved = result.fold((v) => v, (_) => null);
    final payload = resolved?.payload;
    if (payload == null) {
      setState(() => _busy = false);
      _note(s.strings.common.fam_scan_failed);
      return;
    }
    setState(() => _found = true);
    unawaited(_controller.stop());
    // Design: hold the mint check a beat before handing over.
    Timer(const Duration(milliseconds: 620), () {
      if (mounted) widget.onFound((jti: parsed.jti, payload: payload));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final accentLine = _found ? T.petalMint600 : Colors.white;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(T.rXl),
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(
              color: const Color(0xFF14202B),
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.strings.common.fam_scan_failed,
                      textAlign: TextAlign.center,
                      style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            // Corner brackets.
            for (final c in const ['tl', 'tr', 'bl', 'br'])
              PositionedDirectional(
                top: c[0] == 't' ? 26 : null,
                bottom: c[0] == 'b' ? 26 : null,
                start: c[1] == 'l' ? 26 : null,
                end: c[1] == 'r' ? 26 : null,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        top: c[0] == 't' ? BorderSide(color: accentLine, width: 3) : BorderSide.none,
                        bottom: c[0] == 'b' ? BorderSide(color: accentLine, width: 3) : BorderSide.none,
                        start: c[1] == 'l' ? BorderSide(color: accentLine, width: 3) : BorderSide.none,
                        end: c[1] == 'r' ? BorderSide(color: accentLine, width: 3) : BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            if (!_found) const _ScanLine(),
            if (_found)
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(color: T.petalMint600, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.check, size: 32, color: Colors.white),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD914202B)],
                  ),
                ),
                child: Text(
                  _flash ?? (_found ? s.strings.common.fam_code_found : s.strings.common.fam_point_camera),
                  textAlign: TextAlign.center,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Text(s.strings.common.fam_code_hint, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
      const SizedBox(height: 10),
      PButton(s.strings.common.fam_manual_instead,
          variant: BtnVariant.ghost, block: true, ar: s.rtl, onTap: widget.onManual),
    ]);
  }
}

/// The sweeping aqua scan line (`@keyframes scanLine`).
class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // 8% → 88% → 8%, eased.
        final t = _ctrl.value < 0.5 ? _ctrl.value * 2 : (1 - _ctrl.value) * 2;
        final eased = Curves.easeOut.transform(t);
        return Align(
          alignment: Alignment(0, -0.84 + 1.68 * eased),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 26),
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                T.petalAqua.withValues(alpha: 0),
                T.petalAqua,
                T.petalAqua.withValues(alpha: 0),
              ]),
            ),
          ),
        );
      },
    );
  }
}
