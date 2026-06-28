import 'package:flutter/material.dart';
import '_tokens.dart';

/// Localized 404 / unknown-route screen. Used as the `go_router` errorBuilder
/// target. RTL-aware via the ambient [Directionality].
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.onGoHome});

  /// Optional callback to return to a safe route. When null, no action button
  /// is shown (e.g. on public web pages where there is no app home).
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: BalsmColors.ink400),
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
            ],
          ),
        ),
      ),
    );
  }
}
