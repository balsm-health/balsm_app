import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show currentProfileIdProvider;
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'metric_log.dart';
import 'report_flow.dart' show openCheckin;

/// Opens the quick-log sheet (quicklog.jsx `QuickLogSheet`) — what the "+"
/// action in the tab bar / nav rail resolves to. It offers the full check-in
/// plus six one-metric mini flows; picking one and saving persists a check-in
/// carrying only what the patient actually entered.
void showQuickLog(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x612B2B25),
    builder: (sheetContext) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _QuickLogSheet(
            s: s,
            onFullCheckin: () {
              Navigator.pop(sheetContext);
              openCheckin(context);
            },
          ),
        ),
      ),
    ),
  );
}

/// The six one-metric flows, in the design's order.
enum _Metric { bp, glucose, mood, pain, weight, symptoms }

typedef _MetricStyle = ({IconData icon, Color color, Color bg});

const _metricStyles = <_Metric, _MetricStyle>{
  _Metric.bp: (icon: LucideIcons.activity, color: T.petalViolet, bg: T.petalViolet50),
  _Metric.glucose: (icon: LucideIcons.droplet, color: T.petalMint600, bg: T.petalMint50),
  _Metric.mood: (icon: LucideIcons.smile, color: T.petalAqua, bg: T.petalAqua50),
  _Metric.pain: (icon: LucideIcons.zap, color: T.danger, bg: T.dangerBg),
  _Metric.weight: (icon: LucideIcons.scale, color: T.petalBlue, bg: T.petalBlue50),
  _Metric.symptoms: (icon: LucideIcons.stethoscope, color: Color(0xFF9A6E00), bg: Color(0xFFFDF5DC)),
};

String _metricLabel(PatientAppState s, _Metric m) => switch (m) {
      _Metric.bp => s.strings.profile.m_bp,
      _Metric.glucose => s.strings.profile.m_glucose,
      _Metric.mood => s.strings.profile.m_mood,
      _Metric.pain => s.strings.profile.m_pain,
      _Metric.weight => s.strings.profile.m_weight,
      _Metric.symptoms => s.strings.checkin.symptoms,
    };

CheckInMetric _catalogMetric(_Metric m) => switch (m) {
      _Metric.bp => CheckInMetric.bloodPressure,
      _Metric.glucose => CheckInMetric.glucose,
      _Metric.mood => CheckInMetric.mood,
      _Metric.pain => CheckInMetric.pain,
      _Metric.weight => CheckInMetric.weight,
      _Metric.symptoms => CheckInMetric.symptoms,
    };

class _QuickLogSheet extends ConsumerStatefulWidget {
  const _QuickLogSheet({required this.s, required this.onFullCheckin});
  final PatientAppState s;
  final VoidCallback onFullCheckin;
  @override
  ConsumerState<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<_QuickLogSheet> {
  _Metric? active;
  String? savedValue;
  String? savedNote;
  bool saving = false;
  Timer? _closeTimer;

  PatientAppState get s => widget.s;
  bool get ar => s.rtl;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  /// Persists the single metric as a check-in on-device, then flashes the
  /// confirmation and closes. PHI: the captured values are never logged.
  Future<void> _save(MetricLogCapture capture) async {
    if (saving) return;
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return;
    setState(() => saving = true);

    await ref.read(saveCheckInUseCaseProvider).call(CheckIn(
          id: CheckInId.uuid(),
          healthProfileId: profileId,
          recordedAt: DateTime.now(),
          mood: capture.mood,
          painLevel: capture.painLevel,
          painSites: capture.painSites,
          symptoms: capture.symptoms,
          vitals: capture.vitals,
          note: capture.note,
        ));

    if (!mounted) return;
    setState(() {
      saving = false;
      savedValue = capture.summary;
      savedNote = capture.note;
    });
    _closeTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBack = active != null && savedValue == null;
    final style = active == null ? null : _metricStyles[active]!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration:
            const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              if (!showBack)
                Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(T.rPill))),
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
                child: Row(children: [
                  if (showBack) ...[
                    RoundBtn(
                        icon: backArrow(context),
                        ghost: true,
                        iconSize: 18,
                        onTap: () => setState(() => active = null)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      savedValue != null
                          ? s.strings.checkin.ql_saved
                          : (style == null ? s.strings.checkin.ql_title : _metricLabel(s, active!)),
                      style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
                ]),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).padding.bottom.clamp(0, 20)),
              child: RiseIn(key: ValueKey('${active}_${savedValue != null}'), child: _body()),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    if (savedValue != null) return _SavedFlash(s: s, value: savedValue!, note: savedNote);
    if (active == null) return _menu();
    return MetricLog(
      metric: _catalogMetric(active!),
      s: s,
      host: MetricLogHost.standalone,
      onSave: _save,
    );
  }

  Widget _menu() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pressable(
          onTap: widget.onFullCheckin,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: s.accent.main,
              borderRadius: BorderRadius.circular(T.rLg),
              boxShadow: s.accent.boxShadow,
            ),
            child: Row(children: [
              const IconSquare(LucideIcons.clipboardList,
                  bg: Color(0x38FFFFFF), fg: Colors.white, size: 46, iconSize: 23),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.strings.checkin.full_checkin,
                    style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 1),
                Text(s.strings.checkin.ql_full_sub,
                    style: Typo.bodySm(ar: ar).copyWith(color: const Color(0xD9FFFFFF))),
              ])),
              Chevron(rtl: ar, color: const Color(0xBFFFFFFF)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            const Expanded(child: Divider(height: 1, color: T.ink100)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(s.strings.checkin.quick_log_or,
                  style: Typo.meta(ar: ar).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600, color: T.fg4)),
            ),
            const Expanded(child: Divider(height: 1, color: T.ink100)),
          ]),
        ),
        ..._Metric.values.map(_metricRow),
      ]);

  Widget _metricRow(_Metric m) {
    final style = _metricStyles[m]!;
    return PressHighlight(
      onTap: () => setState(() => active = m),
      radius: T.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          IconSquare(style.icon, bg: style.bg, fg: style.color, size: 42, iconSize: 21),
          const SizedBox(width: 14),
          Expanded(
              child: Text(_metricLabel(s, m),
                  style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg1))),
          Chevron(rtl: ar),
        ]),
      ),
    );
  }
}

class _SavedFlash extends StatelessWidget {
  const _SavedFlash({required this.s, required this.value, this.note});
  final PatientAppState s;
  final String value;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Column(children: [
      Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
          child: const Icon(LucideIcons.check, size: 36, color: T.petalMint600)),
      const SizedBox(height: 14),
      Text(s.strings.checkin.ql_saved, style: Typo.heading(ar: ar)),
      const SizedBox(height: 6),
      Text(value, textAlign: TextAlign.center, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rPill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.cloudOff, size: 15, color: T.fg3),
          const SizedBox(width: 8),
          Text(s.strings.common.saved_local, style: Typo.bodySm(ar: ar).copyWith(color: T.fg3)),
        ]),
      ),
      if (note != null)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
          child: Row(children: [
            const Icon(LucideIcons.fileText, size: 14, color: T.fg4),
            const SizedBox(width: 8),
            Expanded(child: Text(note!, style: Typo.bodySm(ar: ar).copyWith(color: T.fg3))),
          ]),
        ),
    ]);
  }
}
