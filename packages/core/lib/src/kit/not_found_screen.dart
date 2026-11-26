import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/core_messages.dart';
import 'status_screen.dart';
import 'tokens.dart';

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
    } on Object catch (_) {
      // Best-effort; nothing sensitive to surface.
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = coreMessagesOf(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.ink400),
              const SizedBox(height: 16),
              Text(
                m.notfound.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                m.notfound.body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ink600),
              ),
              if (onGoHome != null) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: onGoHome, child: Text(m.notfound.go_home)),
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
                label: Text(m.status.title),
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
