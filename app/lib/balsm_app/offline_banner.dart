import 'package:core/core.dart' show onlineProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'tokens.dart';

/// A slim strip shown while no network interface is up.
///
/// Takes its [message] from the caller so the string stays in the app's i69n
/// bundles rather than being hardcoded here.
///
/// Shows nothing while connectivity is unknown. Reporting "offline" during the
/// first frame, before `checkConnectivity` has answered, would flash the banner
/// on every launch.
///
/// This reflects the *interface*, not reachability — a captive-portal Wi-Fi
/// reports online with nothing routable behind it. It is therefore a hint to
/// the user and never a precondition for a request: the app always tries, and a
/// failed attempt is what actually decides whether cached data gets served.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).valueOrNull;
    if (online != false) return const SizedBox.shrink();

    return Material(
      color: T.warningBg,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.cloudOff, size: 15, color: T.ink700),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 13, height: 1.3, color: T.ink700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
