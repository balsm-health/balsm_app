import 'package:flutter/material.dart';
import 'package:core/core.dart';

class AuthRecoveryClaimScreen extends StatefulWidget {
  const AuthRecoveryClaimScreen({super.key, required this.token});
  final String token;

  @override
  State<AuthRecoveryClaimScreen> createState() => _AuthRecoveryClaimScreenState();
}

class _AuthRecoveryClaimScreenState extends State<AuthRecoveryClaimScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _claim();
  }

  Future<void> _claim() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Compliance notice before proceeding.
      final confirmed = await _showComplianceDialog();
      if (!confirmed || !mounted) return;
      // TODO: call RecoveryClaimUseCase with widget.token → navigate to home on success.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              if (_loading) const BalsmLoadingIndicator(),
              if (_error != null) ...[
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
