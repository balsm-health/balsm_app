import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../application/use_cases/revoke_emergency_qr_token_use_case.dart';
import '../../domain/aggregates/emergency_qr_token.dart';

/// Displays the minted QR code for scanning by a first responder, with a live
/// expiry countdown, a revoke action, and a share (copy URL) action.
///
/// The [qrUrl] contains the decryption key in its fragment; it is rendered into
/// the QR and copied locally only. It is never logged or transmitted.
class QrCodeDisplayScreen extends ConsumerStatefulWidget {
  const QrCodeDisplayScreen({
    super.key,
    required this.token,
    required this.qrUrl,
  });

  final EmergencyQrToken token;
  final String qrUrl;

  @override
  ConsumerState<QrCodeDisplayScreen> createState() =>
      _QrCodeDisplayScreenState();
}

class _QrCodeDisplayScreenState extends ConsumerState<QrCodeDisplayScreen> {
  Timer? _ticker;
  late Duration _remaining;
  bool _revoked = false;
  bool _revoking = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.token.expiresAt.difference(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.token.expiresAt.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _isExpired => _remaining.isNegative || _remaining == Duration.zero;

  String get _countdownLabel {
    if (_isExpired) return 'Expired';
    final d = _remaining;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.qrUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency QR link copied')),
    );
  }

  Future<void> _revoke() async {
    setState(() => _revoking = true);
    final result = await ref
        .read(revokeEmergencyQrTokenUseCaseProvider)
        .call(tokenId: widget.token.jti);
    if (!mounted) return;
    setState(() => _revoking = false);
    result.fold(
      (_) => setState(() => _revoked = true),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inactive = _revoked || _isExpired;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency QR')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _revoked
                    ? 'This QR has been revoked.'
                    : 'Show this code to medical staff. It expires automatically.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: BalsmColors.fg2),
              ),
              const SizedBox(height: 24),
              Center(
                child: Opacity(
                  opacity: inactive ? 0.25 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(BalsmRadius.lg),
                      boxShadow: BalsmShadow.sm,
                    ),
                    child: QrImageView(
                      data: widget.qrUrl,
                      version: QrVersions.auto,
                      size: 240,
                      gapless: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: inactive
                        ? BalsmColors.dangerBg
                        : BalsmColors.petalBlue50,
                    borderRadius: BorderRadius.circular(BalsmRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inactive ? Icons.timer_off : Icons.timer_outlined,
                        size: 18,
                        color: inactive
                            ? BalsmColors.danger
                            : BalsmColors.petalBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _revoked ? 'Revoked' : _countdownLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: inactive
                              ? BalsmColors.danger
                              : BalsmColors.petalBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              BalsmButton(
                label: 'Copy link',
                icon: Icons.copy,
                variant: BalsmButtonVariant.secondary,
                onPressed: inactive ? null : _copyUrl,
              ),
              const SizedBox(height: 12),
              if (!_revoked)
                BalsmButton(
                  label: 'Revoke now',
                  icon: Icons.block,
                  variant: BalsmButtonVariant.danger,
                  loading: _revoking,
                  onPressed: _isExpired ? null : _revoke,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
