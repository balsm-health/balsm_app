import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

/// Support-issued recovery-token claim screen (FR-046c/d/e).
///
/// The recovery token arrives via [token]. Claiming re-binds the account to a
/// new email on this device by calling [RecoveryClaimUseCase]. On success we
/// route to the signed-in home destination; on failure we surface the error
/// plus the support fallback. The compliance notice must be acknowledged
/// before the claim is submitted — this preserves the recovery security gate.
class AuthRecoveryClaimScreen extends ConsumerStatefulWidget {
  const AuthRecoveryClaimScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<AuthRecoveryClaimScreen> createState() => _AuthRecoveryClaimScreenState();
}

class _AuthRecoveryClaimScreenState extends ConsumerState<AuthRecoveryClaimScreen> {
  static const _kDeviceId = 'balsm.device_id';
  static const _deviceLabel = 'Balsm Flutter App';

  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid {
    final e = _email.text.trim();
    return e.contains('@') && e.length >= 3;
  }

  Future<void> _claim() async {
    // Double-submit guard: ignore taps while a claim is in flight.
    if (_loading || !_valid) return;

    // Compliance notice must be acknowledged before proceeding.
    final confirmed = await _showComplianceDialog();
    if (!confirmed || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceId = await _ensureDeviceId();
      final result = await ref.read(recoveryClaimUseCaseProvider).call(
            recoveryToken: widget.token,
            newEmail: _email.text.trim(),
            deviceId: deviceId,
            deviceLabel: _deviceLabel,
          );
      if (!mounted) return;
      result.fold(
        (_) => context.goNamed('home'),
        (failure) => setState(() {
          _loading = false;
          _error = failure.message;
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Reuses the same device identifier key as the sign-in flow so the recovered
  /// session binds to a stable device id.
  Future<String> _ensureDeviceId() async {
    final storage = ref.read(secureStorageProvider);
    final existing = await storage.readToken(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = UuidV7.generate().toString();
    await storage.writeToken(_kDeviceId, id);
    return id;
  }

  Future<bool> _showComplianceDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Account Recovery'),
        content: const Text(
          'This will restore your account access. '
          'Note: your on-device health data cannot be restored via this process (FR-046e). '
          'Your on-device data remains on your previous device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BalsmRoundButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onTap: () => Navigator.of(context).pop(),
                semanticLabel: 'Back',
              ),
              const SizedBox(height: 32),
              Text('Account Recovery', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              const Text(
                'Enter the email address you want to use to access your '
                'recovered account.',
              ),
              const SizedBox(height: 16),
              BalsmTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              BalsmButton(
                label: 'Recover my account',
                variant: BalsmButtonVariant.primary,
                loading: _loading,
                onPressed: (_valid && !_loading) ? _claim : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                BalsmErrorBanner(
                  message: _error!,
                  onRetry: _claim,
                ),
                const SizedBox(height: 16),
                const Text('Need help? Contact support@balsm.health'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
