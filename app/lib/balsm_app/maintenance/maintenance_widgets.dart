import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../kit.dart';
import '../screens/profile_subscreens.dart';
import '../tokens.dart';
import '../widgets/balsm_mark.dart';
import 'maintenance_controller.dart';

// Design amber (maintenance.jsx): the strip and sheet use the warning wash
// (T.warningBg = #FDF5DC) with these darker inks for text and icons.
const _amberInk = Color(0xFF6B4E00);
const _amber = Color(0xFF9A6E00);
const _amberLine = Color(0xFFF1E3B5);
const _eyebrowInk = Color(0xFF8A6A10);
const _pageTop = Color(0xFFFDF8E8);

/// Clock used for "Until about 2:00 PM (tomorrow)". Overridable in tests.
final maintenanceClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// "Until about 2:00 PM", "… tomorrow", or "We'll share the end time soon"
/// when no end is announced or the announced one has already passed.
String maintenanceEndText(BuildContext context, PatientAppState s, DateTime? endsAt, DateTime now) {
  final m = s.strings.maintenance;
  if (endsAt == null || !endsAt.isAfter(now)) return m.end_unknown;
  final local = endsAt.toLocal();
  final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local));
  final today = now.toLocal();
  final sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
  return sameDay ? m.until(time) : m.until_tomorrow(time);
}

/// Opens the maintenance sheet: the strip's details, or — with [paused] —
/// "This is paused during maintenance" after a paused action was tapped.
Future<void> showMaintenanceSheet(BuildContext context, {required bool paused}) {
  final s = AppScope.of(context);
  return showAppSheet<void>(
    context,
    useRootNavigator: true,
    textDirection: s.dir,
    builder: (_) => MaintenanceSheet(s: s, paused: paused),
  );
}

class MaintenanceSheet extends ConsumerWidget {
  const MaintenanceSheet({super.key, required this.s, required this.paused});

  final PatientAppState s;
  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = s.strings.maintenance;
    final status = ref.watch(maintenanceProvider);
    final now = ref.watch(maintenanceClockProvider)();
    return Material(
      color: T.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const SheetGrab(),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: T.warningBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(paused ? LucideIcons.circlePause : LucideIcons.wrench, size: 22, color: _amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    header: true,
                    child: Text(paused ? m.paused_title : m.ro_title,
                        style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 2),
                  Text(maintenanceEndText(context, s, status.endsAt, now), style: Typo.meta(ar: s.rtl)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Text(status.message ?? (paused ? m.paused_body(s.gender) : m.ro_body), style: Typo.bodySm(ar: s.rtl)),
            MaintenanceLists(s: s),
            const SizedBox(height: 18),
            PButton(m.got_it, block: true, large: true, ar: s.rtl, onTap: () => Navigator.of(context).pop()),
          ]),
        ),
      ),
    );
  }
}

/// What still works / what's paused — the same lists in the strip's details
/// and in the paused sheet.
class MaintenanceLists extends StatelessWidget {
  const MaintenanceLists({super.key, required this.s});

  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    final m = s.strings.maintenance;
    Widget head(String text) => Padding(
          padding: const EdgeInsetsDirectional.only(top: 12),
          child: Text(text.toUpperCase(), style: Typo.eyebrow(T.fg3, ar: s.rtl)),
        );
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg1))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      head(m.still_available),
      ...[m.ok_view, m.ok_card, m.ok_reminders].map((t) => row(LucideIcons.circleCheck, T.hueMint600, t)),
      head(m.paused_for_now),
      ...[m.paused_log, m.paused_sync, m.paused_signin].map((t) => row(LucideIcons.circlePause, _amber, t)),
    ]);
  }
}

/// Slim strip above the tab bar while maintenance is read-only.
class MaintenanceStrip extends ConsumerWidget {
  const MaintenanceStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(maintenanceProvider);
    if (status.mode != MaintenanceMode.readonly) return const SizedBox.shrink();
    final s = AppScope.of(context);
    final m = s.strings.maintenance;
    final now = ref.watch(maintenanceClockProvider)();
    return Semantics(
      button: true,
      liveRegion: true,
      child: Material(
        color: T.warningBg,
        child: InkWell(
          onTap: () => showMaintenanceSheet(context, paused: false),
          child: Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _amberLine))),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(LucideIcons.wrench, size: 16, color: _amberInk),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.strip_title,
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: _amberInk)),
                  Text(maintenanceEndText(context, s, status.endsAt, now),
                      style: Typo.meta(ar: s.rtl).copyWith(color: _amberInk.withValues(alpha: 0.85))),
                ]),
              ),
              Text(m.strip_details,
                  style: Typo.meta(ar: s.rtl)
                      .copyWith(fontWeight: FontWeight.w700, color: _amberInk, decoration: TextDecoration.underline)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Full-screen page: a full block (signed in or not), or read-only before
/// sign-in. Only the emergency card ([signedIn]) and the country emergency
/// number stay reachable; [onDeviceOnly] offers "Use on this device only"
/// before sign-in while read-only.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key, required this.signedIn, this.onDeviceOnly});

  final bool signedIn;
  final VoidCallback? onDeviceOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final m = s.strings.maintenance;
    final status = ref.watch(maintenanceProvider);
    final now = ref.watch(maintenanceClockProvider)();
    final block = status.blocks;
    final number = s.country.emergencyNumber;
    final body = status.message ?? (signedIn || block ? (block ? m.block_body : m.ro_body) : m.pre_body);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_pageTop, T.surface],
            stops: [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(28, 48, 28, 12),
                        child: Column(children: [
                          const _MarkWithWrench(),
                          const SizedBox(height: 18),
                          Text(m.eyebrow.toUpperCase(), style: Typo.eyebrow(_eyebrowInk, ar: s.rtl)),
                          const SizedBox(height: 12),
                          Semantics(
                            header: true,
                            child: Text(block ? m.block_title : m.ro_title,
                                textAlign: TextAlign.center, style: Typo.heading(ar: s.rtl)),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(body, textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl)),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: T.surface,
                              borderRadius: BorderRadius.circular(T.rPill),
                              border: Border.all(color: T.ink100),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(LucideIcons.clock, size: 15, color: T.fg3),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(maintenanceEndText(context, s, status.endsAt, now),
                                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (signedIn) ...[
                            PButton(m.open_card,
                                icon: LucideIcons.idCard,
                                block: true,
                                large: true,
                                ar: s.rtl,
                                onTap: () => openEmergency(context)),
                            const SizedBox(height: 10),
                          ],
                          if (!signedIn && !block && onDeviceOnly != null) ...[
                            PButton(m.device_only,
                                icon: LucideIcons.smartphone, block: true, large: true, ar: s.rtl, onTap: onDeviceOnly),
                            const SizedBox(height: 10),
                          ],
                          if (number.isNotEmpty) ...[
                            PButton(m.call_emergency(number, s.gender),
                                icon: LucideIcons.phone,
                                variant: BtnVariant.secondary,
                                color: T.danger,
                                block: true,
                                large: true,
                                ar: s.rtl,
                                onTap: () => launchUrl(Uri(scheme: 'tel', path: number))),
                            const SizedBox(height: 10),
                          ],
                          PButton(status.checking ? m.checking : m.check_again(s.gender),
                              icon: LucideIcons.rotateCw,
                              variant: BtnVariant.ghost,
                              block: true,
                              ar: s.rtl,
                              onTap: status.checking ? null : () => ref.read(maintenanceProvider.notifier).check()),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Balsm mark with the amber wrench badge at its inline-end foot.
class _MarkWithWrench extends StatelessWidget {
  const _MarkWithWrench();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(clipBehavior: Clip.none, children: [
        const Positioned.fill(child: Opacity(opacity: 0.9, child: BalsmFlower(size: 88))),
        PositionedDirectional(
          end: -6,
          bottom: -4,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: T.warningBg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(LucideIcons.wrench, size: 17, color: _amber),
          ),
        ),
      ]),
    );
  }
}
