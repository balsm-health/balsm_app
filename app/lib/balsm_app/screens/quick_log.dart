import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:collection/collection.dart';
import 'package:core/core.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'metric_log.dart';
import 'records_detail.dart';
import 'records_screen.dart';
import '../vault/vault_blob.dart';
import 'report_flow.dart';

/// Opens the quick-log sheet (quicklog.jsx `QuickLogSheet`) — what the "+"
/// action in the tab bar / nav rail resolves to. Search + grouped vitals /
/// wellbeing / per-symptom rows, plus the full check-in CTA.
void showQuickLog(BuildContext context) {
  final s = AppScope.of(context);
  showAppSheet<void>(
    context,
    useRootNavigator: true,
    size: SheetSize.lg,
    barrierColor: const Color(0x61141F2B),
    // The sheet drags itself from its header: the route's own drag pops
    // past [PopScope] and would drop unsaved input without asking.
    enableDrag: false,
    textDirection: s.dir,
    builder: (sheetContext) => _QuickLogSheet(
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
  );
}

/// One-metric flows in the design's order (symptoms are their own rows).
enum _Metric { bp, glucose, o2, weight, mood, pain }

enum _QlKind { vital, wellbeing, symptom }

typedef _MetricStyle = ({IconData icon, Color color, Color bg, _QlKind kind});

const _metricStyles = <_Metric, _MetricStyle>{
  _Metric.bp: (icon: LucideIcons.activity, color: T.hueViolet, bg: T.hueViolet50, kind: _QlKind.vital),
  _Metric.glucose: (icon: LucideIcons.droplet, color: T.hueMint600, bg: T.hueMint50, kind: _QlKind.vital),
  _Metric.o2: (icon: LucideIcons.wind, color: T.hueAqua, bg: T.hueAqua50, kind: _QlKind.vital),
  _Metric.weight: (icon: LucideIcons.scale, color: T.hueBlue, bg: T.hueBlue50, kind: _QlKind.vital),
  _Metric.mood: (icon: LucideIcons.smile, color: T.hueAqua, bg: T.hueAqua50, kind: _QlKind.wellbeing),
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

/// Consecutive items of the same kind collapse into one group — the list is
/// already in display order, so this is about what sits next to what.
List<_QlGroup> _groupItems(List<_QlItem> items) =>
    items.splitBetween((a, b) => a.kind != b.kind).map((run) => _QlGroup(kind: run.first.kind, items: run)).toList();

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
  bool saving = false;

  /// What the open flow holds, and whether it may be saved — the header's
  /// Save reads these (quicklog.jsx `FlowSubmit` binds them to the sheet).
  MetricLogCapture? _capture;
  bool _valid = false;

  /// The flow as it opened; leaving asks first only once the entry differs
  /// from it, so undoing an edit needs no prompt.
  MetricLogCapture? _initial;
  bool get _dirty => _capture != null && _initial != null && !_sameEntry(_capture!, _initial!);

  /// Where the discard prompt leads once confirmed; null while it is hidden.
  _Leave? _confirm;

  /// How far the header has dragged the sheet down.
  double _dragDy = 0;
  bool _dragging = false;

  void _dragEnd(DragEndDetails d) {
    final dy = _dragDy;
    final fast = (d.primaryVelocity ?? 0) > 700;
    setState(() {
      _dragDy = 0;
      _dragging = false;
    });
    // quicklog.jsx: past 110px, or a flick past 30px, closes.
    if (dy > 110 || (fast && dy > 30)) _requestClose();
  }

  /// The last save's summary, shown in the "Saved" toast over the list.
  String? _toastValue;
  Timer? _toastTimer;
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
    _toastTimer?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  /// Persists the single metric as a check-in on-device, then returns to the
  /// list with a "Saved" toast, so the next reading is one tap away. PHI: the captured values are never logged.
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

    final checkInId = CheckInId.uuid();
    await ref.read(saveCheckInUseCaseProvider).call(CheckIn(
          id: checkInId,
          healthProfileId: profileId,
          recordedAt: capture.when ?? DateTime.now(),
          mood: capture.mood,
          painLevel: capture.painLevel,
          painSites: capture.painSites,
          symptoms: capture.symptoms,
          symptomDetails: capture.symptomDetails,
          vitals: capture.vitals,
          note: capture.note,
          photoRecordId: photoRecordId,
        ));

    if (!mounted) return;
    setState(() {
      saving = false;
      _openList();
      _toastValue = capture.summary;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(_toastFor, () {
      if (mounted) setState(() => _toastValue = null);
    });
  }

  /// quicklog.jsx `qlToast` — 2.6s.
  static const _toastFor = Duration(milliseconds: 2600);

  /// Back to the list, forgetting the flow. Call inside `setState`.
  void _openList() {
    active = null;
    activeSymptom = null;
    _capture = null;
    _initial = null;
    _valid = false;
    _confirm = null;
  }

  void _onChanged(MetricLogCapture capture, {required bool valid}) {
    setState(() {
      // The first report is the flow's starting state, not an edit.
      _initial ??= capture;
      _capture = capture;
      _valid = valid;
    });
  }

  void _requestBack() => _dirty ? setState(() => _confirm = _Leave.back) : setState(_openList);

  void _requestClose() => _dirty ? setState(() => _confirm = _Leave.close) : Navigator.pop(context);

  /// System back and Escape (quicklog.jsx): dismiss the prompt, else step
  /// back out of the flow, else close the sheet.
  void _onBlockedPop() {
    if (_confirm != null) {
      setState(() => _confirm = null);
    } else {
      _requestBack();
    }
  }

  void _discard() {
    final leave = _confirm;
    setState(_openList);
    if (leave == _Leave.close) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inFlow = active != null || activeSymptom != null;
    final accent = s.accent.main;
    return PopScope(
      canPop: !inFlow && _confirm == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBlockedPop();
      },
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: AnimatedContainer(
          duration: _dragging ? Duration.zero : Motion.base,
          curve: Motion.easeOut,
          transform: Matrix4.translationValues(0, _dragDy, 0),
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          decoration: const BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
          child: Stack(children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => setState(() => _dragging = true),
                onVerticalDragUpdate: (d) => setState(() => _dragDy = math.max(0, _dragDy + d.delta.dy)),
                onVerticalDragEnd: _dragEnd,
                onVerticalDragCancel: () => setState(() {
                  _dragDy = 0;
                  _dragging = false;
                }),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
                  child: Column(children: [
                    const Padding(padding: EdgeInsetsDirectional.only(bottom: 10), child: SheetGrab()),
                    Container(
                      padding: const EdgeInsetsDirectional.only(bottom: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
                      child: Row(children: [
                        if (inFlow) ...[
                          RoundBtn(
                              icon: backArrow(context),
                              semanticLabel: s.strings.common.a11y_back,
                              ghost: true,
                              iconSize: 18,
                              onTap: _requestBack),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            _headerTitle(),
                            style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (inFlow)
                          // quicklog.jsx: Save moves to the header — accent once
                          // the entry is complete, greyed until then.
                          RoundBtn(
                            icon: LucideIcons.check,
                            semanticLabel: s.strings.checkin.ql_save,
                            bg: _valid ? accent : T.ink100,
                            fg: _valid ? Colors.white : T.fg4,
                            outlined: false,
                            iconSize: 19,
                            onTap: _valid && !saving && _capture != null ? () => _save(_capture!) : null,
                          )
                        else
                          RoundBtn(
                              icon: LucideIcons.x,
                              semanticLabel: s.strings.common.a11y_close,
                              ghost: true,
                              iconSize: 18,
                              onTap: () => Navigator.pop(context)),
                      ]),
                    ),
                  ]),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 14, 20, sheetBottomInset(context)),
                  child: RiseIn(key: ValueKey('${active}_$activeSymptom'), child: _body()),
                ),
              ),
            ]),
            // "Saved" with the reading.
            if (_toastValue != null && !inFlow)
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: sheetBottomInset(context, base: 24),
                child: IgnorePointer(child: _SavedToast(s: s, value: _toastValue!)),
              ),
            if (_confirm != null)
              Positioned.fill(
                child: _DiscardPrompt(
                  s: s,
                  onDiscard: _discard,
                  onKeep: () => setState(() => _confirm = null),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  String _headerTitle() {
    if (activeSymptom != null) return symptomLabel(s, activeSymptom!);
    if (active != null) return _metricLabel(s, active!);
    return s.strings.checkin.ql_title;
  }

  Widget _body() {
    if (activeSymptom != null) {
      return MetricLog(
        metric: CheckInMetric.symptoms,
        focusedSymptom: activeSymptom,
        s: s,
        host: MetricLogHost.standalone,
        onChanged: _onChanged,
        onSave: _save,
        onCancel: _requestBack,
      );
    }
    if (active != null) {
      return MetricLog(
        metric: _catalogMetric(active!),
        s: s,
        host: MetricLogHost.standalone,
        onChanged: _onChanged,
        onSave: _save,
        onCancel: _requestBack,
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

enum _Leave { back, close }

/// quicklog.jsx toast — dark, over the list after a save: a mint tick,
/// "Saved" and the reading. Status only; nothing in it is tappable.
class _SavedToast extends StatelessWidget {
  const _SavedToast({required this.s, required this.value});
  final PatientAppState s;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: T.wordmark,
        borderRadius: BorderRadius.circular(T.rLg),
        elevation: 8,
        shadowColor: const Color(0x4714202B),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: T.hueMint, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(s.strings.checkin.ql_saved,
                    style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                if (value.isNotEmpty)
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.meta(ar: ar).copyWith(color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// quicklog.jsx discard prompt — slides over the sheet when leaving a flow
/// with unsaved input. Tapping the dimmed sheet keeps editing.
class _DiscardPrompt extends StatelessWidget {
  const _DiscardPrompt({required this.s, required this.onDiscard, required this.onKeep});
  final PatientAppState s;
  final VoidCallback onDiscard;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    final c = s.strings.checkin;
    return GestureDetector(
      onTap: onKeep,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0x52141F2B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
        ),
        alignment: AlignmentDirectional.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            padding: EdgeInsetsDirectional.fromSTEB(20, 22, 20, sheetBottomInset(context, base: 32)),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
              boxShadow: T.shadowMd,
            ),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: c.ql_discard_title,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(c.ql_discard_title, style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(c.ql_discard_body, style: Typo.bodySm(ar: ar).copyWith(color: T.fg2, height: 1.5)),
                const SizedBox(height: 18),
                PButton(c.ql_discard,
                    variant: BtnVariant.danger, large: true, block: true, accent: s.accent, ar: ar, onTap: onDiscard),
                const SizedBox(height: 10),
                PButton(c.ql_keep_editing,
                    variant: BtnVariant.secondary, large: true, block: true, accent: s.accent, ar: ar, onTap: onKeep),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether two captures hold the same entry — [MetricLogCapture]'s own `==`
/// leaves out the time, the photo and the symptom details.
bool _sameEntry(MetricLogCapture a, MetricLogCapture b) =>
    a == b &&
    a.when == b.when &&
    identical(a.photoBytes, b.photoBytes) &&
    const MapEquality<SymptomId, SymptomDetail>().equals(a.symptomDetails, b.symptomDetails);
