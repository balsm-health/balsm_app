import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/i18n.dart';

/// T166 — Account lockout screen.
///
/// Shown after too many failed sign-in attempts (HTTP 423). Displays a live
/// MM:SS countdown until [lockedUntil]; when it reaches zero, enables a
/// "Try again" button that pops back to the sign-in flow. Also surfaces a
/// support section (mailto + status page).
///
/// RTL-aware (countdown is LTR-isolated) and localized via the module's i18n bundle.
/// PHI constraint: no email/identifier is displayed or logged.
class LockoutScreen extends ConsumerStatefulWidget {
  const LockoutScreen({super.key, required this.lockedUntil});

  /// When the lockout expires.
  final DateTime lockedUntil;

  @override
  ConsumerState<LockoutScreen> createState() => _LockoutScreenState();
}

class _LockoutScreenState extends ConsumerState<LockoutScreen> {
  static const _supportEmail = 'support@balsm.health';

  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final now = DateTime.now();
    final left = widget.lockedUntil.isAfter(now) ? widget.lockedUntil.difference(now) : Duration.zero;
    if (!mounted) return;
    setState(() => _remaining = left);
    if (left == Duration.zero) _timer?.cancel();
  }

  bool get _expired => _remaining == Duration.zero;

  String get _countdown {
    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _emailSupport() async {
    final uri = Uri(scheme: 'mailto', path: _supportEmail);
    await _launch(uri);
  }

  // G6 fix: link to the in-app PUBLIC status page (`{BASE_URL}/status`) instead
  // of the old hardcoded external `https://status.balsm.health`. Reachable
  // without auth; support (mailto) is one further tap away there (SC-011a).
  void _openStatus() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StatusScreen()),
    );
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort; nothing sensitive to surface.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Typed, module-owned strings — compile-time checked; Messages_ar extends
    // Messages, so untranslated Arabic keys fall back to English.
    final m = authMessagesOf(Localizations.localeOf(context).languageCode).lockout;

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Icon(
                Icons.lock_clock_outlined,
                size: 48,
                color: BalsmColors.warning,
              ),
              const SizedBox(height: 24),
              Text(
                m.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: BalsmColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                m.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: BalsmColors.ink600,
                ),
              ),
              const SizedBox(height: 32),
              // Countdown — force LTR so MM:SS reads correctly under RTL.
              if (!_expired)
                Center(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _countdown,
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: BalsmColors.ink900,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              BalsmButton(
                label: m.retry,
                onPressed: _expired ? () => Navigator.of(context).maybePop() : null,
              ),
              const Spacer(),
              // Support section
              Text(
                m.needHelp,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: BalsmColors.ink700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _SupportRow(
                icon: Icons.mail_outline,
                label: m.contactSupport(_supportEmail),
                onTap: _emailSupport,
              ),
              const SizedBox(height: 4),
              _SupportRow(
                icon: Icons.public,
                label: m.serviceStatus,
                onTap: _openStatus,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BalsmRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: BalsmColors.appAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: BalsmColors.appAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: BalsmColors.ink300),
          ],
        ),
      ),
    );
  }
}
