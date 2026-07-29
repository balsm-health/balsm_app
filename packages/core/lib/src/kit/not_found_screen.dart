import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '_tokens.dart';
import 'status_screen.dart';

/// Localized 404 / unknown-route screen. Used as the `go_router` errorBuilder
/// target. RTL-aware via the ambient [Directionality].
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.onGoHome});

  /// Optional callback to return to a safe route. When null, no action button
  /// is shown (e.g. on public web pages where there is no app home).
  final VoidCallback? onGoHome;

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: StatusScreen.supportEmail,
      query: 'subject=Balsm support',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort; nothing sensitive to surface.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: BalsmColors.ink400),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'The page you are looking for does not exist.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BalsmColors.ink600),
              ),
              if (onGoHome != null) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: onGoHome, child: const Text('Go home')),
              ],
              // G6 / SC-011a: a hard-blocking screen must expose a no-auth
              // support channel + the public status page in ≤2 taps.
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StatusScreen(),
                  ),
                ),
                icon: const Icon(Icons.public, size: 18),
                label: const Text('Service status'),
              ),
              TextButton.icon(
                onPressed: _emailSupport,
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text(StatusScreen.supportEmail),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
