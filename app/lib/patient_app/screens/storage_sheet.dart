import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/badges.dart';

/// Storage & sync sheet (storage.jsx `StorageSyncSheet`) — the single-active-
/// cloud backup flow. Phases: idle (provider picker) → connecting / migrating
/// (animated ring + stepped checklist) → done, plus confirm-disconnect.
void showStorageSync(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false, // gated by phase — close via the X / Done button
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C2B2B25),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _StorageSyncSheet(s: s),
        ),
      ),
    ),
  );
}

// Migration step labels — app i69n keys.
const _migrateSteps = [
  'store_step_prepare',
  'store_step_checkins',
  'store_step_records',
  'store_step_rx',
  'store_step_verify',
];

class _StorageSyncSheet extends StatefulWidget {
  const _StorageSyncSheet({required this.s});
  final PatientAppState s;
  @override
  State<_StorageSyncSheet> createState() => _StorageSyncSheetState();
}

class _StorageSyncSheetState extends State<_StorageSyncSheet> {
  String phase = 'idle'; // idle | connecting | migrating | done | confirm_disconnect
  String? target;
  int progress = 0;
  Timer? _timer;

  PatientAppState get s => widget.s;
  String get active => s.storageProvider;
  bool get ar => s.rtl;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _runPhase(String to, String mode) {
    setState(() { target = to; phase = mode; progress = 0; });
    final total = mode == 'connecting' ? 1 : _migrateSteps.length;
    final ms = mode == 'connecting' ? 900 : 550;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => progress++);
      if (progress >= total) {
        t.cancel();
        s.switchCloudProvider(to);
        Future.delayed(const Duration(milliseconds: 250), () { if (mounted) setState(() => phase = 'done'); });
      }
    });
  }

  void _select(String to) {
    if (to == active) return;
    if (to == 'local') {
      setState(() { target = 'local'; phase = 'confirm_disconnect'; });
    } else if (active == 'local') {
      _runPhase(to, 'connecting');
    } else {
      _runPhase(to, 'migrating');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canClose = phase == 'idle' || phase == 'done' || phase == 'confirm_disconnect';
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(children: [
            Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
              child: Row(children: [
                const Icon(LucideIcons.hardDrive, size: 20, color: T.fg3),
                const SizedBox(width: 10),
                Expanded(child: Text(s.strings.storage, style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700))),
                if (canClose) RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
              ]),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            physics: phase == 'idle' ? null : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            child: switch (phase) {
              'connecting' => _connecting(),
              'migrating' => _migrating(),
              'done' => _done(),
              'confirm_disconnect' => _confirmDisconnect(),
              _ => _idle(),
            },
          ),
        ),
      ]),
    );
  }

  // ── IDLE: provider selector ────────────────────────────────
  // The fabricated per-category storage-usage breakdown was removed — P001 has
  // no real storage-metering provider, so only the (real) active-target picker
  // is shown. Reintroduce a breakdown here only when it is backed by real data.
  Widget _idle() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
        child: Text(s.strings.store_choose_help,
            style: Typo.meta(ar: ar).copyWith(height: 1.5)),
      ),
      for (final p in const ['local', 'icloud', 'gdrive']) _providerCard(p),
    ]);
  }

  Widget _providerCard(String p) {
    final cfg = storageCfg(p);
    final isActive = active == p;
    final isLocal = p == 'local';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: isActive ? null : () => _select(p),
        scale: isActive ? 1.0 : 0.99,
        // `transition: all var(--dur-base) var(--ease-out)` on active swap.
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? cfg.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rXl),
            border: Border.all(color: isActive ? cfg.color : T.border, width: 1.5),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: Motion.base, curve: Motion.easeOut,
              width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? cfg.color : T.ink100,
                borderRadius: BorderRadius.circular(T.rMd)),
              child: Icon(cfg.icon, size: 22, color: isActive ? Colors.white : T.fg3),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(s.t(cfg.label), style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                if (isLocal) ...[
                  const SizedBox(width: 8),
                  Pill(s.strings.store_always_on, kind: PillKind.neutral, dot: false, ar: ar,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1)),
                ],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                if (isActive) ...[
                  Icon(LucideIcons.checkCircle, size: 12, color: cfg.color),
                  const SizedBox(width: 5),
                ],
                Text(
                  isActive
                      ? (isLocal ? s.strings.store_local_only : s.strings.store_backed)
                      : (isLocal ? s.strings.store_no_backup : s.strings.store_tap_connect),
                  style: Typo.meta(ar: ar).copyWith(
                      fontSize: FS.xs, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? cfg.color : T.fg4)),
              ]),
            ])),
            if (isActive)
              Icon(LucideIcons.checkCircle2, size: 22, color: cfg.color)
            else
              Chevron(rtl: ar),
          ]),
        ),
      ),
    );
  }

  // ── CONNECTING ─────────────────────────────────────────────
  Widget _connecting() {
    final cfg = storageCfg(target!);
    return RiseIn(child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
      child: Column(children: [
        Container(
          width: 72, height: 72, alignment: Alignment.center,
          decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(T.rXl)),
          child: Spinner(size: 34, stroke: 3, color: cfg.color),
        ),
        const SizedBox(height: 18),
        Text(s.strings.store_connecting(s.t(cfg.label)),
            textAlign: TextAlign.center, style: Typo.heading(ar: ar).copyWith(fontSize: FS.xl)),
        const SizedBox(height: 6),
        Text(s.strings.store_auto_start,
            textAlign: TextAlign.center, style: Typo.meta(ar: ar)),
      ]),
    ));
  }

  // ── MIGRATING: from→to, progress ring, stepped checklist ───
  Widget _migrating() {
    final from = storageCfg(active);
    final cfg = storageCfg(target!);
    final pct = (progress / _migrateSteps.length * 100).round();
    return RiseIn(child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Column(children: [
        // From → To strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rXl)),
          child: Row(children: [
            _miniIco(from),
            const SizedBox(width: 12),
            const Icon(LucideIcons.arrowRight, size: 18, color: T.fg3),
            const SizedBox(width: 12),
            _miniIco(cfg),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.strings.store_migrating, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              Text('${s.t(from.label)} → ${s.t(cfg.label)}', style: Typo.meta(ar: ar)),
            ])),
            Text('$pct%', style: Typo.num(size: FS.md, weight: FontWeight.w700, color: cfg.color)),
          ]),
        ),
        const SizedBox(height: 20),
        // Progress ring (animated stroke)
        RingProgress(progress: pct / 100, color: cfg.color, size: 80,
            label: '$pct%', labelStyle: Typo.num(size: FS.md, weight: FontWeight.w700)),
        const SizedBox(height: 20),
        // Step checklist
        for (var i = 0; i < _migrateSteps.length; i++) _stepRow(i, cfg),
      ]),
    ));
  }

  Widget _miniIco(({IconData icon, Color color, Color bg, Color border, dynamic label}) cfg) => Container(
        width: 40, height: 40, alignment: Alignment.center,
        decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(T.rMd)),
        child: Icon(cfg.icon, size: 20, color: cfg.color),
      );

  Widget _stepRow(int i, ({IconData icon, Color color, Color bg, Color border, dynamic label}) cfg) {
    final done = i < progress;
    final act = i == progress; // current in-flight step
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.easeOut,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: act ? cfg.bg : Colors.transparent,
        borderRadius: BorderRadius.circular(T.rMd),
      ),
      child: Row(children: [
        SizedBox(
          width: 17, height: 17,
          child: done
              ? const Icon(LucideIcons.checkCircle2, size: 17, color: T.petalMint600)
              : act
                  ? Spinner(size: 17, stroke: 2, color: cfg.color)
                  : const Icon(LucideIcons.circle, size: 17, color: T.ink200),
        ),
        const SizedBox(width: 10),
        Text(s.t(_migrateSteps[i]),
            style: Typo.bodySm(ar: ar).copyWith(
                fontWeight: act ? FontWeight.w600 : FontWeight.w400,
                color: done ? T.fg4 : (act ? T.fg1 : T.fg4))),
      ]),
    );
  }

  // ── DONE ───────────────────────────────────────────────────
  Widget _done() {
    final cfg = storageCfg(target!);
    final toLocal = target == 'local';
    return RiseIn(child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 8),
      child: Column(children: [
        Container(
          width: 68, height: 68, alignment: Alignment.center,
          decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
          child: const Icon(LucideIcons.check, size: 32, color: T.petalMint600),
        ),
        const SizedBox(height: 16),
        Text(
          toLocal
              ? s.strings.store_removed_done
              : s.strings.store_synced_done,
          textAlign: TextAlign.center, style: Typo.heading(ar: ar).copyWith(fontSize: FS.xl),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: cfg.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(cfg.icon, size: 18, color: cfg.color),
            const SizedBox(width: 10),
            Flexible(child: Text(
              toLocal
                  ? s.strings.store_device_only
                  : s.strings.store_synced_with(s.t(cfg.label)),
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg1))),
          ]),
        ),
        const SizedBox(height: 16),
        PButton(s.strings.store_done, variant: BtnVariant.primary, large: true, block: true,
            accent: s.accent, ar: ar, onTap: () => Navigator.pop(context)),
      ]),
    ));
  }

  // ── CONFIRM DISCONNECT ─────────────────────────────────────
  Widget _confirmDisconnect() {
    final cur = storageCfg(active);
    return RiseIn(child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFEF3F2), borderRadius: BorderRadius.circular(T.rXl), border: Border.all(color: const Color(0xFFFECDCA))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(LucideIcons.cloudOff, size: 22, color: T.danger),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.strings.store_remove_q,
                  style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              const SizedBox(height: 4),
              Text(
                s.strings.store_remove_help(s.t(cur.label)),
                style: Typo.meta(ar: ar).copyWith(height: 1.5)),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        _DangerButton(label: s.strings.store_remove_cta, onTap: () => _runPhase('local', 'connecting')),
        const SizedBox(height: 10),
        PButton(s.strings.cancel, variant: BtnVariant.secondary, block: true, ar: ar,
            onTap: () => setState(() { phase = 'idle'; target = null; })),
      ]),
    ));
  }
}

/// Red destructive button (`.btn danger`).
class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final ar = AppScope.of(context).rtl;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 56, width: double.infinity, alignment: Alignment.center,
        decoration: BoxDecoration(color: T.danger, borderRadius: BorderRadius.circular(T.rLg)),
        child: Text(label, style: Typo.body(ar: ar).copyWith(fontSize: FS.lg, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}
