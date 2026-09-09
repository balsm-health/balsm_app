import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show activeProfileProvider, currentProfileIdProvider, currentUserIdProvider;
import 'package:records/records.dart' show RecordType;
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'checkin_shared.dart';
import 'metric_log.dart';
import 'records_detail.dart' show showAddRecord;
import 'records_screen.dart' show recordTypeLabelOne, recordTypeStyle;
import '../vault/vault_blob.dart';
import 'report_flow.dart' show openCheckin;

/// Opens the quick-log sheet (quicklog.jsx `QuickLogSheet`) — what the "+"
/// action in the tab bar / nav rail resolves to. Search + grouped vitals /
/// wellbeing / per-symptom rows, plus the full check-in CTA.
void showQuickLog(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x61141F2B),
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
            onAddRecord: (type) {
              Navigator.pop(sheetContext);
              showAddRecord(context, initialType: type);
            },
          ),
        ),
      ),
    ),
  );
}

/// One-metric flows in the design's order (symptoms are their own rows).
enum _Metric { bp, glucose, o2, weight, mood, pain }

enum _QlKind { vital, wellbeing, symptom }

typedef _MetricStyle = ({IconData icon, Color color, Color bg, _QlKind kind});

const _metricStyles = <_Metric, _MetricStyle>{
  _Metric.bp: (icon: LucideIcons.activity, color: T.petalViolet, bg: T.petalViolet50, kind: _QlKind.vital),
  _Metric.glucose: (icon: LucideIcons.droplet, color: T.petalMint600, bg: T.petalMint50, kind: _QlKind.vital),
  _Metric.o2: (icon: LucideIcons.wind, color: T.petalAqua, bg: T.petalAqua50, kind: _QlKind.vital),
  _Metric.weight: (icon: LucideIcons.scale, color: T.petalBlue, bg: T.petalBlue50, kind: _QlKind.vital),
  _Metric.mood: (icon: LucideIcons.smile, color: T.petalAqua, bg: T.petalAqua50, kind: _QlKind.wellbeing),
  _Metric.pain: (icon: LucideIcons.zap, color: T.danger, bg: T.dangerBg, kind: _QlKind.wellbeing),
};

const _symptomGold = Color(0xFF9A6E00);
const _symptomGoldBg = Color(0xFFFDF5DC);

String _metricLabel(PatientAppState s, _Metric m) => switch (m) {
      _Metric.bp => s.strings.profile.m_bp,
      _Metric.glucose => s.strings.profile.m_glucose,
      _Metric.o2 => s.strings.profile.m_o2,
      _Metric.mood => s.strings.profile.m_mood,
      _Metric.pain => s.strings.profile.m_pain,
      _Metric.weight => s.strings.profile.m_weight,
    };

CheckInMetric _catalogMetric(_Metric m) => switch (m) {
      _Metric.bp => CheckInMetric.bloodPressure,
      _Metric.glucose => CheckInMetric.glucose,
      _Metric.o2 => CheckInMetric.spo2,
      _Metric.mood => CheckInMetric.mood,
      _Metric.pain => CheckInMetric.pain,
      _Metric.weight => CheckInMetric.weight,
    };

class _QlItem {
  const _QlItem({
    required this.kind,
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    this.metric,
    this.symptom,
  });
  final _QlKind kind;
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final _Metric? metric;
  final SymptomId? symptom;
}

class _QlGroup {
  _QlGroup({required this.kind, required this.items});
  final _QlKind kind;
  final List<_QlItem> items;
}

List<_QlGroup> _groupItems(List<_QlItem> items) {
  final groups = <_QlGroup>[];
  for (final item in items) {
    if (groups.isNotEmpty && groups.last.kind == item.kind) {
      groups.last.items.add(item);
    } else {
      groups.add(_QlGroup(kind: item.kind, items: [item]));
    }
  }
  return groups;
}

class _QuickLogSheet extends ConsumerStatefulWidget {
  const _QuickLogSheet({required this.s, required this.onFullCheckin, required this.onAddRecord});
  final PatientAppState s;
  final VoidCallback onFullCheckin;
  final ValueChanged<RecordType> onAddRecord;
  @override
  ConsumerState<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<_QuickLogSheet> {
  _Metric? active;
  SymptomId? activeSymptom;
  String? savedValue;
  String? savedNote;
  bool saving = false;
  Timer? _closeTimer;
  late final TextEditingController searchCtrl;

  PatientAppState get s => widget.s;
  bool get ar => s.rtl;

  @override
  void initState() {
    super.initState();
    searchCtrl = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  /// Persists the single metric as a check-in on-device, then flashes the
  /// confirmation and closes. PHI: the captured values are never logged.
  ///
  /// [currentProfileIdProvider] is a plain (non-async) read of whatever
  /// [activeProfileProvider] has resolved so far — on a cold session that
  /// FutureProvider may not have finished ensuring the self health profile
  /// yet, so a one-shot `ref.read` here could still be null even for a
  /// signed-in user, and the tap would silently do nothing. Await the
  /// provider's own future instead so the first save after launch waits for
  /// it rather than dropping the capture.
  Future<void> _save(MetricLogCapture capture) async {
    if (saving) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => saving = true);
    final profileId = await ref.read(activeProfileProvider.future);
    if (profileId == null) {
      if (mounted) setState(() => saving = false);
      return;
    }
    if (!mounted) return;

    String? photoRecordId;
    if (capture.photoBytes != null) {
      photoRecordId = await persistPhotoRecord(
        ref,
        bytes: Uint8List.fromList(capture.photoBytes!),
        title: AppScope.of(context).strings.settings.add_photo,
      );
    }

    await ref.read(saveCheckInUseCaseProvider).call(CheckIn(
          id: CheckInId.uuid(),
          healthProfileId: profileId,
          recordedAt: capture.when ?? DateTime.now(),
          mood: capture.mood,
          painLevel: capture.painLevel,
          painSites: capture.painSites,
          symptoms: capture.symptoms,
          vitals: capture.vitals,
          note: capture.note,
          photoRecordId: photoRecordId,
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
    final showBack = (active != null || activeSymptom != null) && savedValue == null;
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
                        onTap: () => setState(() {
                              active = null;
                              activeSymptom = null;
                            })),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _headerTitle(),
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
              padding: EdgeInsets.fromLTRB(20, 14, 20, sheetBottomInset(context)),
              child: RiseIn(key: ValueKey('${active}_${activeSymptom}_${savedValue != null}'), child: _body()),
            ),
          ),
        ]),
      ),
    );
  }

  String _headerTitle() {
    if (savedValue != null) return s.strings.checkin.ql_saved;
    if (activeSymptom != null) return symptomLabel(s, activeSymptom!);
    if (active != null) return _metricLabel(s, active!);
    return s.strings.checkin.ql_title;
  }

  Widget _body() {
    if (savedValue != null) return _SavedFlash(s: s, value: savedValue!, note: savedNote);
    if (activeSymptom != null) {
      return MetricLog(
        metric: CheckInMetric.symptoms,
        focusedSymptom: activeSymptom,
        s: s,
        host: MetricLogHost.standalone,
        onSave: _save,
      );
    }
    if (active != null) {
      return MetricLog(
        metric: _catalogMetric(active!),
        s: s,
        host: MetricLogHost.standalone,
        onSave: _save,
      );
    }
    return _menu();
  }

  List<_QlItem> _allItems() {
    final metrics = _Metric.values.map((m) {
      final style = _metricStyles[m]!;
      return _QlItem(
        kind: style.kind,
        icon: style.icon,
        color: style.color,
        bg: style.bg,
        label: _metricLabel(s, m),
        metric: m,
      );
    });
    final symptoms = [...symptomIcons]..sort((a, b) => symptomLabel(s, a.$1).compareTo(symptomLabel(s, b.$1)));
    return [
      ...metrics,
      ...symptoms.map((e) => _QlItem(
            kind: _QlKind.symptom,
            icon: e.$2,
            color: _symptomGold,
            bg: _symptomGoldBg,
            label: symptomLabel(s, e.$1),
            symptom: e.$1,
          )),
    ];
  }

  Widget _menu() {
    final q = searchCtrl.text.trim().toLowerCase();
    final items = _allItems();
    final filtered = q.isEmpty ? items : items.where((it) => it.label.toLowerCase().contains(q)).toList();
    final showCta = q.isEmpty || s.strings.checkin.full_checkin.toLowerCase().contains(q);
    final records =
        RecordType.values.where((type) => q.isEmpty || recordTypeLabelOne(s, type).toLowerCase().contains(q)).toList();
    final empty = filtered.isEmpty && records.isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _searchField(),
      if (showCta) ...[
        _fullCheckinCta(),
        if (filtered.isNotEmpty) _labelledRule(s.strings.checkin.quick_log_or, top: 0, bottom: 10),
      ],
      if (empty)
        _noResults()
      else ...[
        ..._groupItems(filtered).map(_groupCard),
        if (records.isNotEmpty) ...[
          _labelledRule(s.strings.checkin.ql_add_records, top: 14, bottom: 12),
          _recordRow(records),
        ],
      ],
    ]);
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: searchCtrl,
        style: Typo.body(ar: ar).copyWith(color: T.fg1, fontSize: FS.lg),
        decoration: InputDecoration(
          hintText: s.strings.checkin.ql_search,
          hintStyle: Typo.body(ar: ar).copyWith(color: T.fg4, fontSize: FS.lg),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: const Icon(LucideIcons.search, size: 16, color: T.fg4),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 44),
          suffixIcon: searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(LucideIcons.x, size: 15, color: T.fg4),
                  onPressed: searchCtrl.clear,
                ),
          border: _searchBorder(T.border),
          enabledBorder: _searchBorder(T.border),
          focusedBorder: _searchBorder(s.accent.main),
        ),
      ),
    );
  }

  OutlineInputBorder _searchBorder(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rMd),
        borderSide: BorderSide(color: c, width: 1.5),
      );

  Widget _fullCheckinCta() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Pressable(
        onTap: widget.onFullCheckin,
        scale: 0.985,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [s.accent.main, s.accent.d],
            ),
            borderRadius: BorderRadius.circular(T.rLg),
            boxShadow: s.accent.boxShadow,
          ),
          child: Stack(children: [
            Positioned(
              top: -14,
              right: ar ? null : -12,
              left: ar ? -12 : null,
              child: Transform.rotate(
                angle: 12 * math.pi / 180,
                child: Icon(LucideIcons.sparkle, size: 64, color: Colors.white.withValues(alpha: 0.14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.bodySm(ar: ar).copyWith(color: const Color(0xD9FFFFFF))),
                ])),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0x2EFFFFFF), shape: BoxShape.circle),
                  child: Chevron(rtl: ar, size: 16, color: Colors.white),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _noResults() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
        child: Column(children: [
          const Icon(LucideIcons.searchX, size: 26, color: T.fg4),
          const SizedBox(height: 8),
          Text(s.strings.checkin.ql_no_results,
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg4)),
        ]),
      );

  Widget _groupCard(_QlGroup g) {
    final label = switch (g.kind) {
      _QlKind.vital => s.strings.checkin.ql_vitals,
      _QlKind.wellbeing => s.strings.checkin.ql_wellbeing,
      _QlKind.symptom => s.strings.checkin.symptoms,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          // `text-transform: uppercase` on the group header (quicklog.jsx).
          // Applied here, not baked into the bundle: `symptoms` is shared
          // with rows and chips that must stay sentence case.
          child: Text(label.toUpperCase(), style: Typo.eyebrow(T.fg4, ar: ar).copyWith(letterSpacing: ar ? 0 : 0.88)),
        ),
        PCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: g.items.indexed.map((e) {
              final last = e.$1 == g.items.length - 1;
              return _itemRow(e.$2, last: last);
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _itemRow(_QlItem item, {required bool last}) {
    return PressHighlight(
      onTap: () => setState(() {
        if (item.symptom != null) {
          activeSymptom = item.symptom;
        } else {
          active = item.metric;
        }
      }),
      radius: last ? T.rLg : 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: T.ink50)),
        ),
        child: Row(children: [
          IconSquare(item.icon, bg: item.bg, fg: item.color, size: 40, iconSize: 19),
          const SizedBox(width: 14),
          Expanded(
              child: Text(item.label, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg1))),
          Chevron(rtl: ar),
        ]),
      ),
    );
  }

  /// A hairline with a caption sitting in the gap.
  Widget _labelledRule(String label, {required double top, required double bottom}) => Padding(
        padding: EdgeInsets.only(top: top, bottom: bottom),
        child: Row(children: [
          const Expanded(child: Divider(height: 1, color: T.ink100)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                softWrap: false,
                style: Typo.meta(ar: ar).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: T.fg4)),
          ),
          const Expanded(child: Divider(height: 1, color: T.ink100)),
        ]),
      );

  Widget _recordRow(List<RecordType> types) {
    return Row(
      children: types.indexed.expand((e) {
        final tile = Expanded(child: _recordShortcut(e.$2));
        if (e.$1 == 0) return [tile];
        return [const SizedBox(width: 8), tile];
      }).toList(),
    );
  }

  /// Straight into the add-record sheet with the type already chosen.
  Widget _recordShortcut(RecordType type) {
    final style = recordTypeStyle(type);
    return PressHighlight(
      onTap: () => widget.onAddRecord(type),
      radius: T.rLg,
      border: Border.all(color: T.border, width: 1.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Column(children: [
          IconSquare(style.icon, bg: style.bg, fg: style.fg, size: 40, iconSize: 20),
          const SizedBox(height: 8),
          Text(recordTypeLabelOne(s, type),
              textAlign: TextAlign.center,
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
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
      Text(value, textAlign: TextAlign.center, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w500)),
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
            const Icon(LucideIcons.fileText, size: 13, color: T.fg4),
            const SizedBox(width: 8),
            Expanded(child: Text(note!, style: Typo.bodySm(ar: ar).copyWith(color: T.fg3))),
          ]),
        ),
    ]);
  }
}
