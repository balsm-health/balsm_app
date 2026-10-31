import 'dart:async';
import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/body_map.dart';
import '../widgets/mood_face.dart';
import 'checkin_shared.dart';

/// One day's readings — mood heroes, metric rows, symptoms cards — from every
/// check-in logged that date, in the order they were logged.
///
/// Port of the Claude Design `DayRecordsScreen`. Each reading shows its own
/// check-in's [CheckIn.recordedAt]; the domain does not store per-metric
/// clocks, so we never invent them.
///
/// Every reading is the patient's own, so it can be deleted three ways: its
/// `⋮` menu, a swipe toward the start edge, or Select for several at once.
/// Each asks first, then stores the edit straight away. A check-in emptied
/// this way is deleted, photo included.
class DayRecordsScreen extends ConsumerStatefulWidget {
  const DayRecordsScreen({super.key, required this.checkIns});

  /// The day's check-ins, oldest first (see `groupCheckInsByDay`). Never empty.
  final List<CheckIn> checkIns;

  static Future<void> open(BuildContext context, List<CheckIn> day) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayRecordsScreen(checkIns: day)));
  }

  @override
  ConsumerState<DayRecordsScreen> createState() => _DayRecordsScreenState();
}

/// A reading on the day: which check-in, and which of its metrics.
typedef _Key = (CheckInId, CheckInMetric);

class _DayRecordsScreenState extends ConsumerState<DayRecordsScreen> {
  static const _toastFor = Duration(milliseconds: 2500);

  late List<CheckIn> _shown = widget.checkIns;

  /// The row swiped open, showing its Delete.
  _Key? _open;
  bool _selecting = false;
  final _selected = <_Key>{};
  String? _toast;
  Timer? _toastTimer;

  // Read once up front: a store still running when the screen closes must
  // not reach for ref.
  late final UpdateCheckInUseCase _update;
  late final RecordsDataSource _records;
  late final DeleteRecordDocumentUseCase _deleteRecord;
  late final UserId? _userId;

  /// Stores run one after another, so a later edit never lands first.
  Future<void> _saving = Future.value();

  @override
  void initState() {
    super.initState();
    _update = ref.read(updateCheckInUseCaseProvider);
    _records = ref.read(recordsDataSourceProvider);
    _deleteRecord = ref.read(deleteRecordDocumentUseCaseProvider);
    _userId = ref.read(currentUserIdProvider);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  /// An emptied check-in loses its photo first, so a failure part-way never
  /// leaves a hidden photo with no check-in pointing at it.
  Future<void> _persist(CheckIn edited) async {
    final photoId = RecordDocumentId.fromString(edited.photoRecordId);
    final user = _userId;
    if (edited.isEmpty && photoId != null && user != null) {
      final photo = await _records.find(photoId, scope: user);
      if (photo != null) await _deleteRecord(photo, scope: user);
    }
    await _update(edited);
  }

  void _startSelect([_Key? first]) => setState(() {
        _open = null;
        _selecting = true;
        _selected
          ..clear()
          ..addAll([if (first != null) first]);
      });

  void _endSelect() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _toggle(_Key k) => setState(() => _selected.contains(k) ? _selected.remove(k) : _selected.add(k));

  /// Asks before deleting [readings]; nothing changes on Cancel.
  Future<void> _askDelete(List<_Reading> readings, {required String day}) async {
    if (readings.isEmpty) return;
    final c = AppScope.of(context).strings.checkin;
    final one = readings.length == 1 ? readings.single : null;
    // English names sit mid-sentence; lowercasing leaves Arabic untouched.
    final title = c.rec_del_title(one?.label.toLowerCase() ?? c.rec_count(readings.length));
    final body = one != null ? c.rec_del_body_one(day, one.time) : c.rec_del_body_n(day);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x6114202B),
      builder: (_) => _ConfirmDelete(title: title, body: body),
    );
    if (!mounted) return;
    if (ok != true) {
      setState(() => _open = null);
      return;
    }
    // One store per check-in touched, however many of its readings went.
    final gone = <CheckInId, List<CheckInMetric>>{};
    for (final r in readings) {
      (gone[r.checkIn.id] ??= []).add(r.metric);
    }
    final shown = [
      for (final ci in _shown)
        if (gone[ci.id] case final metrics?) metrics.fold(ci, (x, m) => x.without(m)) else ci,
    ];
    for (final edited in shown.where((ci) => gone.containsKey(ci.id))) {
      _saving = _saving.then((_) => _persist(edited));
    }
    _toastTimer?.cancel();
    setState(() {
      _shown = shown;
      _open = null;
      _selecting = false;
      _selected.clear();
      _toast = c.rec_deleted(one?.label ?? c.rec_count(readings.length));
    });
    _toastTimer = Timer(_toastFor, () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// The `⋮` popover, opened under its button and aligned to its end edge.
  /// True when the patient picked Delete.
  Future<bool> _openMenu(BuildContext button, _Reading r) async {
    setState(() => _open = null);
    final s = AppScope.of(context);
    final box = button.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final x = s.rtl ? rect.left : rect.right;
    final delete = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(x, rect.bottom + 4, overlay.size.width - x, overlay.size.height - rect.bottom),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x3314202B),
      menuPadding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 184),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rLg),
        side: const BorderSide(color: T.ink100),
      ),
      popUpAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 120), curve: Motion.easeOut),
      items: [
        PopupMenuItem<bool>(
          value: true,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Icon(LucideIcons.trash2, size: 18, color: T.danger),
            const SizedBox(width: 10),
            Text(s.strings.checkin.rec_delete,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.danger)),
          ]),
        ),
      ],
    );
    return delete == true;
  }

  /// [checkIn]'s vitals and pain as metric rows, in the design's order.
  List<_Reading> _metricRows(PatientAppState s, CheckIn checkIn, String time) {
    final c = s.strings.checkin;
    final v = checkIn.vitals;
    final glucose = v.glucoseFasting ?? v.glucosePostMeal ?? v.glucoseRandom;
    _Reading row(CheckInMetric metric, IconData icon, String label, String value, String unit, Color color, Color bg) =>
        _Reading(
            checkIn: checkIn,
            time: time,
            metric: metric,
            icon: icon,
            label: label,
            value: value,
            unit: unit,
            color: color,
            bg: bg);
    return [
      if (v.systolic != null && v.diastolic != null)
        row(CheckInMetric.bloodPressure, LucideIcons.activity, s.strings.profile.m_bp, '${v.systolic}/${v.diastolic}',
            c.unit_bp, T.hueViolet, T.hueViolet50),
      if (glucose != null)
        row(CheckInMetric.glucose, LucideIcons.droplet, s.strings.profile.m_glucose, '$glucose', c.unit_glu,
            T.hueMint600, T.hueMint50),
      if (v.spo2 != null)
        row(CheckInMetric.spo2, LucideIcons.wind, s.strings.profile.m_o2, '${v.spo2}', c.unit_spo2, T.hueBlue,
            T.hueBlue50),
      if (v.heartRate != null)
        row(CheckInMetric.heartRate, LucideIcons.heartPulse, s.strings.profile.m_pulse, '${v.heartRate}', c.unit_bpm,
            T.hueViolet, T.hueViolet50),
      if (v.weightKg != null)
        row(CheckInMetric.weight, LucideIcons.scale, s.strings.profile.m_weight, _weight(v.weightKg!), c.unit_kg,
            T.hueBlue, T.hueBlue50),
      if (checkIn.reportsPain)
        row(CheckInMetric.pain, LucideIcons.zap, s.strings.profile.m_pain, '${checkIn.painLevel.value}/10', '',
            T.danger, T.dangerBg),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.strings.checkin;
    final d = _shown.first.recordedAt.toLocal();
    final day = '${d.day} ${checkInMonthShort(s, d)}';
    final localizations = MaterialLocalizations.of(context);
    String timeOf(CheckIn ci) => localizations.formatTimeOfDay(TimeOfDay.fromDateTime(ci.recordedAt.toLocal()));

    final moods = [
      for (final ci in _shown)
        if (ci.mood case final mood?)
          _Reading(
            checkIn: ci,
            time: timeOf(ci),
            metric: CheckInMetric.mood,
            icon: LucideIcons.smile,
            label: s.strings.profile.m_mood,
            value: moodLabel(s, mood.score),
            unit: '',
            color: T.fg1,
            bg: T.ink50,
          ),
    ];
    final rows = [for (final ci in _shown) ..._metricRows(s, ci, timeOf(ci))];
    final symptoms = [
      for (final ci in _shown)
        if (ci.symptoms.isNotEmpty)
          _Reading(
            checkIn: ci,
            time: timeOf(ci),
            metric: CheckInMetric.symptoms,
            icon: LucideIcons.stethoscope,
            label: c.symptoms_n('${ci.symptoms.length}'),
            value: '',
            unit: '',
            color: const Color(0xFF9A6E00),
            bg: const Color(0xFFFDF5DC),
          ),
    ];
    final all = [...moods, ...rows, ...symptoms];
    final allOn = all.isNotEmpty && all.every((r) => _selected.contains(r.key));
    final empty = _shown.every((ci) => ci.isEmpty);
    final toast = _toast;

    void ask(List<_Reading> rs) => _askDelete(rs, day: day);

    Widget swipe(_Reading r, {double radius = 0, required Widget child}) => _SwipeRow(
          open: _open == r.key,
          radius: radius,
          deleteLabel: c.rec_delete_short,
          selecting: _selecting,
          selected: _selected.contains(r.key),
          label: r.label,
          onOpen: () => setState(() => _open = r.key),
          onClose: () => setState(() => _open = _open == r.key ? null : _open),
          onDelete: () => ask([r]),
          onLongPress: () => _startSelect(r.key),
          onToggle: () => _toggle(r.key),
          child: child,
        );

    Widget lead(_Reading r) => _selecting
        ? Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: _Check(on: _selected.contains(r.key)),
          )
        : const SizedBox.shrink();

    Widget more(_Reading r) => _selecting
        ? const SizedBox(width: 8)
        : _MoreBtn(
            reading: r,
            onTap: (button) async {
              if (await _openMenu(button, r)) ask([r]);
            },
          );

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _endSelect();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: ContentColumn(
          maxWidth: 720,
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const PadTop(),
              if (!_selecting)
                AppBarRow(children: [
                  RoundBtn(
                      icon: backArrow(context),
                      semanticLabel: s.strings.common.a11y_back,
                      onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(child: Text(day, style: Typo.heading(ar: s.rtl))),
                  if (all.isNotEmpty)
                    PButton(c.rec_select,
                        variant: BtnVariant.ghost, size: BtnSize.sm, ar: s.rtl, onTap: () => _startSelect()),
                ])
              else
                AppBarRow(children: [
                  RoundBtn(icon: LucideIcons.x, semanticLabel: c.rec_select_done, onTap: _endSelect),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _selected.isEmpty ? c.rec_select_title : c.rec_selected(_selected.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Typo.heading(ar: s.rtl),
                      ),
                    ),
                  ),
                  PButton(allOn ? c.rec_clear_all : c.rec_select_all,
                      variant: BtnVariant.ghost,
                      size: BtnSize.sm,
                      ar: s.rtl,
                      onTap: () => setState(() {
                            if (allOn) {
                              _selected.clear();
                            } else {
                              _selected.addAll(all.map((r) => r.key));
                            }
                          })),
                ]),
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: [
                  for (final m in moods)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
                      child: swipe(
                        m,
                        radius: T.rLg,
                        child: Container(
                          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(T.rLg),
                            border: Border.all(color: s.accent.bg),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.65],
                              colors: [s.accent.bg, T.cream50],
                            ),
                          ),
                          child: Row(children: [
                            lead(m),
                            MoodFace(
                                level: m.checkIn.mood!.score, size: 40, color: moodColors[m.checkIn.mood!.score - 1]),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.value,
                                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                                const SizedBox(height: 2),
                                _TimeMeta(time: m.time, prefix: '${m.label} · '),
                              ]),
                            ),
                            more(m),
                          ]),
                        ),
                      ),
                    ),
                  if (moods.isNotEmpty) const SizedBox(height: 4),
                  if (rows.isNotEmpty)
                    PCard(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(T.rLg - 1),
                        child: Column(
                          children: rows.indexed
                              .map((e) => swipe(
                                    e.$2,
                                    child: _MetricLine(
                                      row: e.$2,
                                      last: e.$1 == rows.length - 1,
                                      lead: lead(e.$2),
                                      trail: more(e.$2),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  for (final sym in symptoms)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                      child: swipe(
                        sym,
                        radius: T.rLg,
                        child: PCard(
                          flat: true,
                          padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 6, 13),
                          child: Row(children: [
                            lead(sym),
                            IconSquare(sym.icon, bg: sym.bg, fg: sym.color, size: 38, iconSize: 19, radius: T.rMd),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(sym.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                                const SizedBox(height: 2),
                                _TimeMeta(time: sym.time),
                              ]),
                            ),
                            more(sym),
                          ]),
                        ),
                      ),
                    ),
                  for (final ci in _shown) ...[
                    // Where it hurt — the body map as the patient marked it.
                    if (ci.painSites.isNotEmpty)
                      PCard(
                        margin: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            Expanded(
                              child: Text(c.body_marked,
                                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                            ),
                            _TimeMeta(time: timeOf(ci)),
                          ]),
                          const SizedBox(height: 12),
                          BodyMapPreview(sites: ci.painSites),
                        ]),
                      ),
                    // The check-in's photo (records-vault back-reference) — design
                    // DayRecordsScreen renders attachments inline with the readings.
                    if (ci.photoRecordId != null && !ci.isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                        child: RecordAttachmentThumb(recordId: ci.photoRecordId!, height: 160),
                      ),
                  ],
                  if (empty) _EmptyDay(text: c.day_empty),
                  // Room for the toast and the selection bar over the last row.
                  const SizedBox(height: 112),
                ]),
              ),
            ]),
            if (_selecting)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: _SelectionBar(
                  label: _selected.isEmpty ? c.rec_delete_short : c.rec_delete_n(c.rec_count(_selected.length)),
                  onDelete: _selected.isEmpty ? null : () => ask(all.where((r) => _selected.contains(r.key)).toList()),
                ),
              ),
            if (toast != null)
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                child: _DoneToast(text: toast),
              ),
          ]),
        ),
      ),
    );
  }

  static String _weight(double kg) => kg == kg.roundToDouble() ? '${kg.round()}' : kg.toStringAsFixed(1);
}

/// One deletable reading as the day screen shows it.
class _Reading {
  const _Reading({
    required this.checkIn,
    required this.time,
    required this.metric,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.bg,
  });

  /// The check-in it was logged in, and that check-in's clock time.
  final CheckIn checkIn;
  final String time;
  final CheckInMetric metric;
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color bg;

  _Key get key => (checkIn.id, metric);
}

/// Design `SwipeRow`: dragging toward the start edge reveals Delete; a swipe
/// past half the width asks to delete at once. Long-press starts Select; while
/// selecting, a tap toggles the row instead.
class _SwipeRow extends StatefulWidget {
  const _SwipeRow({
    required this.open,
    required this.radius,
    required this.deleteLabel,
    required this.selecting,
    required this.selected,
    required this.label,
    required this.onOpen,
    required this.onClose,
    required this.onDelete,
    required this.onLongPress,
    required this.onToggle,
    required this.child,
  });
  final bool open;
  final double radius;
  final String deleteLabel;
  final bool selecting;
  final bool selected;
  final String label;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final Widget child;

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow> {
  static const _reveal = 88.0;

  /// Signed offset while a finger is down; null when the row rests.
  double? _drag;
  double _base = 0;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // The row slides toward the start edge: left in English, right in Arabic.
    final dir = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    final rest = widget.open ? dir * _reveal : 0.0;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final content = TweenAnimationBuilder<double>(
        tween: Tween(end: _drag ?? rest),
        duration: _drag != null ? Duration.zero : const Duration(milliseconds: 200),
        curve: Motion.easeOut,
        builder: (context, offset, child) {
          final amt = math.max(0.0, offset * dir);
          return Stack(children: [
            if (amt > 0)
              PositionedDirectional(
                top: 0,
                bottom: 0,
                end: 0,
                width: math.max(_reveal, amt),
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      color: T.danger,
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.trash2, size: 20, color: Colors.white),
                        const SizedBox(height: 4),
                        Text(widget.deleteLabel,
                            style: Typo.meta(ar: s.rtl)
                                .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            Transform.translate(offset: Offset(offset, 0), child: child),
          ]);
        },
        child: widget.child,
      );
      final row = widget.selecting
          ? Semantics(
              checked: widget.selected,
              label: widget.label,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onToggle, child: content),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.open ? widget.onClose : null,
              onLongPress: widget.onLongPress,
              onHorizontalDragStart: (_) {
                _base = rest;
                _dx = 0;
                setState(() => _drag = rest);
              },
              onHorizontalDragUpdate: (e) {
                _dx += e.delta.dx;
                setState(() => _drag = ((_base + _dx) * dir).clamp(0.0, w) * dir);
              },
              onHorizontalDragEnd: (_) => _settle(w),
              onHorizontalDragCancel: () => _settle(w),
              child: content,
            );
      return ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: row);
    });
  }

  void _settle(double w) {
    final a = (_drag ?? 0).abs();
    setState(() => _drag = null);
    if (a > w * 0.5) {
      widget.onDelete();
    } else if (a > _reveal / 2) {
      widget.onOpen();
    } else {
      widget.onClose();
    }
  }
}

/// Design `Check`: the row's tick box while selecting.
class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Motion.easeOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: on ? AccentScope.of(context).main : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: on ? null : Border.all(color: T.ink300, width: 2),
        ),
        child: on ? const Icon(LucideIcons.check, size: 16, color: Colors.white) : null,
      );
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.row, required this.last, required this.lead, required this.trail});
  final _Reading row;
  final bool last;
  final Widget lead;
  final Widget trail;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: last ? null : const Border(bottom: BorderSide(color: T.ink50)),
      ),
      child: Row(children: [
        lead,
        IconSquare(row.icon, bg: row.bg, fg: row.color, size: 42, iconSize: 20, radius: T.rMd),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(height: 2),
            _TimeMeta(time: row.time),
          ]),
        ),
        const SizedBox(width: 10),
        _ValueText(row: row),
        trail,
      ]),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText({required this.row});
  final _Reading row;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: row.value, style: Typo.num(size: FS.md, weight: FontWeight.w700, color: T.fg1)),
          if (row.unit.isNotEmpty)
            TextSpan(text: ' ${row.unit}', style: Typo.num(size: FS.xs, weight: FontWeight.w500, color: T.fg4)),
        ]),
        maxLines: 1,
      );
}

class _TimeMeta extends StatelessWidget {
  const _TimeMeta({required this.time, this.prefix = ''});
  final String time;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // One paragraph, so a narrow row trims it with an ellipsis instead of
    // overflowing (Arabic units leave the label column little room).
    return Text.rich(
      TextSpan(children: [
        if (prefix.isNotEmpty) TextSpan(text: prefix),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: 5),
            child: Icon(LucideIcons.clock, size: 12, color: T.fg3),
          ),
        ),
        TextSpan(text: time),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Typo.meta(ar: s.rtl),
    );
  }
}

/// The row's `⋮` (design `More`): opens the reading's menu under itself.
class _MoreBtn extends StatelessWidget {
  const _MoreBtn({required this.reading, required this.onTap});
  final _Reading reading;
  final void Function(BuildContext button) onTap;

  @override
  Widget build(BuildContext context) => RoundBtn(
        icon: LucideIcons.ellipsisVertical,
        semanticLabel: AppScope.of(context).strings.checkin.rec_more(reading.label),
        ghost: true,
        iconSize: 18,
        fg: T.fg3,
        onTap: () => onTap(context),
      );
}

/// Design's delete alert: what goes and when it was recorded, then Delete or
/// Cancel. Pops `true` to delete.
class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rXl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child:
                  IconSquare(LucideIcons.trash2, bg: T.dangerBg, fg: T.danger, size: 44, iconSize: 22, radius: T.rMd),
            ),
            const SizedBox(height: 14),
            Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            const SizedBox(height: 6),
            Text(body, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2, height: 1.5)),
            const SizedBox(height: 20),
            PButton(s.strings.checkin.rec_delete_short,
                variant: BtnVariant.danger,
                large: true,
                block: true,
                ar: s.rtl,
                onTap: () => Navigator.pop(context, true)),
            const SizedBox(height: 10),
            PButton(s.strings.common.cancel,
                variant: BtnVariant.secondary,
                large: true,
                block: true,
                ar: s.rtl,
                onTap: () => Navigator.pop(context, false)),
          ]),
        ),
      ),
    );
  }
}

/// Pinned under the list while selecting; disabled until a row is ticked.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.label, required this.onDelete});
  final String label;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: T.ink100)),
        boxShadow: [BoxShadow(color: Color(0x0F14202B), offset: Offset(0, -6), blurRadius: 18)],
      ),
      child: PButton(label,
          icon: LucideIcons.trash2, variant: BtnVariant.danger, large: true, block: true, ar: s.rtl, onTap: onDelete),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(children: [
        const Icon(LucideIcons.calendarX, size: 28, color: T.fg4),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, height: 1.5)),
      ]),
    );
  }
}

/// Design's dark "deleted" notice, announced to screen readers as it appears.
class _DoneToast extends StatelessWidget {
  const _DoneToast({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: T.ink800, borderRadius: BorderRadius.circular(T.rLg), boxShadow: T.shadowLg),
        child: Row(children: [
          const Icon(LucideIcons.check, size: 17, color: T.hueMint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}
