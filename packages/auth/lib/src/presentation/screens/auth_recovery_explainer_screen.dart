import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthRecoveryExplainerScreen extends StatelessWidget {
  const AuthRecoveryExplainerScreen({super.key});

  Future<void> _contactSupport() async {
    final uri = Uri(scheme: 'mailto', path: 'support@balsm.health');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort.
    }
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
              Text(
                'Account Recovery',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              const BalsmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('To recover your account, contact support with 2 of these 4 facts:'),
                    SizedBox(height: 12),
                    Text('• Your registered email address'),
                    Text('• Your date of birth'),
                    Text('• Your Balsm handle (@username)'),
                    Text('• A medication name you recorded'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Note: Recovery restores account access only. '
                'On-device health data is encrypted and cannot be recovered by Balsm.',
              ),
              const Spacer(),
              BalsmButton(
                label: 'Contact support',
                onPressed: _contactSupport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
