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
import '../widgets/delete_kit.dart';
import '../widgets/mood_face.dart';
import 'checkin_shared.dart';

/// One day's readings — mood heroes, metric rows, symptoms cards — from every
/// check-in logged that date, in the order they were logged.
///
/// Port of the Claude Design `DayRecordsScreen`. Each reading shows its own
/// check-in's [CheckIn.recordedAt]; the domain does not store per-metric
/// clocks, so we never invent them.
///
/// Every reading is the patient's own, so it can be deleted with the shared
/// [DeleteKit]: its `⋮` menu, a swipe toward the start edge, or Select for
/// several at once. Each asks first, then stores the edit straight away. A
/// check-in emptied this way is deleted, photo included.
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

class _DayRecordsScreenState extends ConsumerState<DayRecordsScreen> with DeleteKit<DayRecordsScreen, _Key> {
  late List<CheckIn> _shown = widget.checkIns;

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

  /// Asks before deleting [readings]; nothing changes on Cancel.
  void _ask(List<_Reading> readings, {required String day}) {
    if (readings.isEmpty) return;
    final c = AppScope.of(context).strings.checkin;
    final one = readings.length == 1 ? readings.single : null;
    final what = one?.label ?? c.rec_count(readings.length);
    confirmDelete(
      // English names sit mid-sentence; lowercasing leaves Arabic untouched.
      title: AppScope.of(context).strings.common.del_title(one?.label.toLowerCase() ?? what),
      body: one != null ? c.rec_del_body_one(day, one.time) : c.rec_del_body_n(day),
      done: what,
      onConfirmed: () {
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
        setState(() => _shown = shown);
      },
    );
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
    final empty = _shown.every((ci) => ci.isEmpty);

    void ask(List<_Reading> rs) => _ask(rs, day: day);

    Widget swipe(_Reading r, {double radius = 0, required Widget child}) =>
        kitSwipe(item: r.key, label: r.label, onDelete: () => ask([r]), radius: radius, child: child);

    Widget more(_Reading r) => kitMore(label: r.label, menuLabel: c.rec_delete, onDelete: () => ask([r]));

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting) endSelect();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: ContentColumn(
          maxWidth: 720,
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const PadTop(),
              if (!selecting)
                AppBarRow(children: [
                  RoundBtn(
                      icon: backArrow(context),
                      semanticLabel: s.strings.common.a11y_back,
                      onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(child: Text(day, style: Typo.heading(ar: s.rtl))),
                  if (all.isNotEmpty)
                    PButton(s.strings.common.del_select,
                        variant: BtnVariant.ghost, size: BtnSize.sm, ar: s.rtl, onTap: () => startSelect()),
                ])
              else
                kitSelectAppBar(all.map((r) => r.key), title: c.rec_select_title),
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
                            kitCheck(m.key),
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
                                      lead: kitCheck(e.$2.key),
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
                            kitCheck(sym.key),
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
                  // Room for the notice and the selection bar over the last row.
                  const SizedBox(height: 112),
                ]),
              ),
            ]),
            ...deleteKitOverlays(
              count: c.rec_count,
              onDeleteSelected: () => ask(all.where((r) => selected.contains(r.key)).toList()),
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
