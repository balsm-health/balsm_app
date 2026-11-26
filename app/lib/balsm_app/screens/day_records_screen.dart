import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';

import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/body_map.dart';
import '../widgets/delete_kit.dart';
import '../widgets/entry_attribution.dart';
import '../widgets/mood_face.dart';
import 'checkin_shared.dart';
import 'quick_log.dart';

/// One day's readings — mood heroes, metric rows, symptoms cards — from every
/// check-in logged that date, in the order they were logged.
///
/// Port of the Claude Design `DayRecordsScreen`. Each reading shows its own
/// check-in's [CheckIn.recordedAt]; the domain does not store per-metric
/// clocks, so we never invent them.
///
/// Every reading — the patient's own or one someone else logged — can be deleted with the shared
/// [DeleteKit]: its `⋮` menu, a swipe toward the start edge, or Select for
/// several at once. Each asks first, then stores the edit straight away. A
/// check-in emptied this way is deleted, photo included.
///
/// A reading can also be edited (home-base-mc.jsx `DayRecordsScreen`): tap it
/// or pick Edit from its `⋮`, and the quick-log form opens on it, prefilled.
/// Each symptom has its own row to edit it.
class DayRecordsScreen extends ConsumerStatefulWidget {
  const DayRecordsScreen({required this.checkIns, super.key});

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
  /// The day on screen — kept apart from the check-ins shown, which an edit
  /// can empty by moving its only reading to another day.
  late final DateTime _day = widget.checkIns.first.recordedAt.toLocal();

  /// Whose check-ins these are; the screen follows that profile's live store.
  late final HealthProfileId _owner = widget.checkIns.first.healthProfileId;

  /// The day's check-ins as stored now: an edit or a delete shows once the
  /// store has it. The route's snapshot stands in until the store answers.
  List<CheckIn> _dayOf(AsyncValue<List<CheckIn>> stored) => switch (stored.value) {
        final all? => checkInsOnDay(all, _day),
        null => widget.checkIns,
      };

  // Read once up front: a store still running when the screen closes must
  // not reach for ref.
  late final UpdateCheckInUseCase _update;
  late final RecordsDataSource _records;
  late final DeleteRecordDocumentUseCase _deleteRecord;
  late final UserFileStore _files;
  late final UserId? _userId;
  late final HealthProfileId? _profileId;

  /// Stores run one after another, so a later edit never lands first.
  Future<void> _saving = Future.value();

  /// Check-ins a delete is still storing. The screen reads the day from the
  /// store, which has not shown that delete yet, so a second delete on the same
  /// check-in starts from this and does not bring the first one back.
  final _inFlight = <CheckInId, CheckIn>{};

  @override
  void initState() {
    super.initState();
    _update = ref.read(updateCheckInUseCaseProvider);
    _records = ref.read(recordsDataSourceProvider);
    _deleteRecord = ref.read(deleteRecordDocumentUseCaseProvider);
    _files = ref.read(userFileStoreProvider);
    _userId = ref.read(currentUserIdProvider);
    _profileId = ref.read(currentProfileIdProvider);
  }

  /// An emptied check-in loses its photo first, so a failure part-way never
  /// leaves a hidden photo with no check-in pointing at it.
  Future<void> _persist(CheckIn edited) async {
    final photoId = RecordDocumentId.fromString(edited.photoRecordId);
    final user = _userId;
    final profile = _profileId;
    if (edited.isEmpty && photoId != null && user != null && profile != null) {
      final photo = await _records.find(photoId, scope: profile);
      if (photo != null) await _deleteRecord(photo, scope: user, profile: profile);
    }
    await _update(edited);
  }

  /// The check-in's photo, decrypted for the edit form; null when there is
  /// none or it cannot be read (the check-in then keeps it as it is).
  Future<Uint8List?> _photoOf(CheckIn checkIn) async {
    final id = RecordDocumentId.fromString(checkIn.photoRecordId);
    final profile = _profileId;
    if (id == null || profile == null) return null;
    final path = (await _records.find(id, scope: profile))?.filePath;
    if (path == null) return null;
    try {
      return await _files.read(path, scope: _userId);
    } on StorageDecodeException {
      return null;
    }
  }

  /// Opens the quick-log form on [r] (one [symptom] of it, for a symptoms
  /// reading). The stored edit reaches the screen through the store; a
  /// reading moved to another day leaves this one.
  Future<void> _edit(_Reading r, {SymptomId? symptom}) async {
    final photo = await _photoOf(r.checkIn);
    if (!mounted) return;
    final d = r.metric == CheckInMetric.symptoms ? null : _dayLabel();
    await showEditReading(
      context,
      checkIn: r.checkIn,
      metric: r.metric,
      symptom: symptom,
      photoBytes: photo,
      onDelete: d == null ? null : () => _ask([r], day: d),
    );
  }

  String _dayLabel() => '${_day.day} ${checkInMonthShort(AppScope.of(context), _day)}';

  /// Asks before deleting [readings]; nothing changes on Cancel.
  void _ask(List<_Reading> readings, {required String day}) {
    if (readings.isEmpty) return;
    final c = AppScope.of(context).strings.checkin;
    final one = readings.length == 1 ? readings.single : null;
    final what = one?.label ?? c.rec_count(readings.length);
    unawaited(
      confirmDelete(
        // English names sit mid-sentence; lowercasing leaves Arabic untouched.
        title: AppScope.of(context).strings.common.del_title(one?.label.toLowerCase() ?? what),
        body: one != null ? c.rec_del_body_one(day, one.time) : c.rec_del_body_n(day),
        done: what,
        onConfirmed: () {
          if (!mounted) return;
          // One store per check-in touched, however many of its readings went.
          final gone = <CheckInId, List<CheckInMetric>>{};
          for (final r in readings) {
            (gone[r.checkIn.id] ??= []).add(r.metric);
          }
          // From the check-ins as stored now, or as an earlier delete is still
          // storing them, so that delete holds.
          for (final ci in _dayOf(ref.read(profileCheckInsProvider(_owner)))) {
            if (gone[ci.id] case final metrics?) {
              final edited = metrics.fold(_inFlight[ci.id] ?? ci, (x, m) => x.without(m));
              _inFlight[ci.id] = edited;
              _saving = _saving.then((_) => _persist(edited)).whenComplete(() {
                if (identical(_inFlight[ci.id], edited)) _inFlight.remove(ci.id);
              });
            }
          }
        },
      ),
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
          bg: bg,
        );
    return [
      if (v.systolic != null && v.diastolic != null)
        row(
          CheckInMetric.bloodPressure,
          LucideIcons.activity,
          s.strings.profile.m_bp,
          '${v.systolic}/${v.diastolic}',
          c.unit_bp,
          AppColors.hueViolet,
          AppColors.hueViolet50,
        ),
      if (glucose != null)
        row(
          CheckInMetric.glucose,
          LucideIcons.droplet,
          s.strings.profile.m_glucose,
          '$glucose',
          c.unit_glu,
          AppColors.hueMint600,
          AppColors.hueMint50,
        ),
      if (v.spo2 != null)
        row(
          CheckInMetric.spo2,
          LucideIcons.wind,
          s.strings.profile.m_o2,
          '${v.spo2}',
          c.unit_spo2,
          AppColors.hueBlue,
          AppColors.hueBlue50,
        ),
      if (v.heartRate != null)
        row(
          CheckInMetric.heartRate,
          LucideIcons.heartPulse,
          s.strings.profile.m_pulse,
          '${v.heartRate}',
          c.unit_bpm,
          AppColors.hueViolet,
          AppColors.hueViolet50,
        ),
      if (v.weightKg case final weightKg?)
        row(
          CheckInMetric.weight,
          LucideIcons.scale,
          s.strings.profile.m_weight,
          _weight(weightKg),
          c.unit_kg,
          AppColors.hueBlue,
          AppColors.hueBlue50,
        ),
      if (checkIn.reportsPain)
        row(
          CheckInMetric.pain,
          LucideIcons.zap,
          s.strings.profile.m_pain,
          '${checkIn.painLevel.value}/10',
          '',
          AppColors.danger,
          AppColors.dangerBackground,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final shown = _dayOf(ref.watch(profileCheckInsProvider(_owner)));
    final c = s.strings.checkin;
    final day = _dayLabel();
    final localizations = MaterialLocalizations.of(context);
    String timeOf(CheckIn ci) => localizations.formatTimeOfDay(TimeOfDay.fromDateTime(ci.recordedAt.toLocal()));

    final moods = [
      for (final ci in shown)
        if (ci.mood case final mood?)
          _Reading(
            checkIn: ci,
            time: timeOf(ci),
            metric: CheckInMetric.mood,
            icon: LucideIcons.smile,
            label: s.strings.profile.m_mood,
            value: moodLabel(s, mood.score),
            unit: '',
            color: AppColors.textPrimary,
            bg: AppColors.ink50,
          ),
    ];
    final rows = [for (final ci in shown) ..._metricRows(s, ci, timeOf(ci))];
    final symptoms = [
      for (final ci in shown)
        if (ci.symptoms.isNotEmpty)
          _Reading(
            checkIn: ci,
            time: timeOf(ci),
            metric: CheckInMetric.symptoms,
            icon: LucideIcons.stethoscope,
            label: c.symptoms_n('${ci.symptoms.length}'),
            value: '',
            unit: '',
            color: AppColors.warningInk,
            bg: AppColors.warningBackground,
          ),
    ];
    final all = [...moods, ...rows, ...symptoms];
    final empty = shown.every((ci) => ci.isEmpty);

    void ask(List<_Reading> rs) => _ask(rs, day: day);

    Widget swipe(_Reading r, {required Widget child, double radius = 0}) =>
        kitSwipe(item: r.key, label: r.label, onDelete: () => ask([r]), radius: radius, child: child);

    Widget more(_Reading r, {bool editable = true}) => kitMore(
          label: r.label,
          menuLabel: c.rec_delete,
          onDelete: () => ask([r]),
          onEdit: editable ? () => _edit(r) : null,
        );

    /// The reading opens in the edit form when tapped.
    Widget tapToEdit(_Reading r, Widget child) => Semantics(
          button: true,
          onTapHint: s.strings.common.a11y_edit,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _edit(r), child: child),
        );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting) endSelect();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: ContentColumn(
          maxWidth: 720,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PadTop(),
                  if (!selecting)
                    AppBarRow(
                      children: [
                        RoundBtn(
                          icon: backArrow(context),
                          semanticLabel: s.strings.common.a11y_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(day, style: Typo.heading(ar: s.rtl))),
                        if (all.isNotEmpty)
                          PButton(
                            s.strings.common.del_select,
                            variant: BtnVariant.ghost,
                            size: BtnSize.sm,
                            ar: s.rtl,
                            onTap: startSelect,
                          ),
                      ],
                    )
                  else
                    kitSelectAppBar(all.map((r) => r.key), title: c.rec_select_title),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final m in moods)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
                            child: swipe(
                              m,
                              radius: AppRadii.lg,
                              child: tapToEdit(
                                m,
                                Container(
                                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                    border: Border.all(color: s.accent.bg),
                                    gradient: LinearGradient(
                                      begin: AlignmentDirectional.topStart,
                                      end: AlignmentDirectional.bottomEnd,
                                      stops: const [0.0, 0.65],
                                      colors: [s.accent.bg, AppColors.cream50],
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      kitCheck(m.key),
                                      MoodFace(
                                        level: m.checkIn.mood!.score,
                                        size: 40,
                                        color: moodColors[m.checkIn.mood!.score - 1],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.value,
                                              style: Typo.body(ar: s.rtl)
                                                  .copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            _TimeMeta(time: m.time, prefix: '${m.label} · '),
                                          ],
                                        ),
                                      ),
                                      more(m),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (moods.isNotEmpty) const SizedBox(height: 4),
                        if (rows.isNotEmpty)
                          PCard(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.lg - 1),
                              child: Column(
                                children: rows.indexed
                                    .map(
                                      (e) => swipe(
                                        e.$2,
                                        child: tapToEdit(
                                          e.$2,
                                          _MetricLine(
                                            row: e.$2,
                                            last: e.$1 == rows.length - 1,
                                            lead: kitCheck(e.$2.key),
                                            trail: more(e.$2),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        for (final sym in symptoms)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                            child: swipe(
                              sym,
                              radius: AppRadii.lg,
                              child: PCard(
                                flat: true,
                                padding: EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 6, 13),
                                      child: Row(
                                        children: [
                                          kitCheck(sym.key),
                                          IconSquare(sym.icon, bg: sym.bg, fg: sym.color),
                                          const SizedBox(width: 13),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sym.label,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Typo.body(ar: s.rtl).copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                _TimeMeta(time: sym.time),
                                                if (sym.checkIn.history.isAttributed)
                                                  Padding(
                                                    padding: const EdgeInsetsDirectional.only(top: 4),
                                                    child: EntryAttributionChip(history: sym.checkIn.history),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          more(sym, editable: false),
                                        ],
                                      ),
                                    ),
                                    if (!selecting)
                                      ...sym.checkIn.symptoms.map(
                                        (id) => _SymptomLine(
                                          label: symptomLabel(s, id),
                                          editLabel: s.strings.common.a11y_edit,
                                          onTap: () => _edit(sym, symptom: id),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        for (final ci in shown) ...[
                          // Where it hurt — the body map as the patient marked it.
                          if (ci.painSites.isNotEmpty)
                            PCard(
                              margin: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c.body_marked,
                                          style: Typo.body(ar: s.rtl)
                                              .copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      _TimeMeta(time: timeOf(ci)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  BodyMapPreview(sites: ci.painSites),
                                ],
                              ),
                            ),
                          // The check-in's photo (records-vault back-reference) — design
                          // DayRecordsScreen renders attachments inline with the readings.
                          if (ci.photoRecordId case final photoRecordId? when !ci.isEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                              child: RecordAttachmentThumb(recordId: photoRecordId, height: 160),
                            ),
                        ],
                        if (empty) _EmptyDay(text: c.day_empty),
                        // Room for the notice and the selection bar over the last row.
                        const SizedBox(height: 112),
                      ],
                    ),
                  ),
                ],
              ),
              ...deleteKitOverlays(
                count: c.rec_count,
                onDeleteSelected: () => ask(all.where((r) => selected.contains(r.key)).toList()),
              ),
            ],
          ),
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

/// One symptom of a check-in, under its symptoms card: tap to edit it.
class _SymptomLine extends StatelessWidget {
  const _SymptomLine({required this.label, required this.editLabel, required this.onTap});
  final String label;
  final String editLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      label: label,
      onTapHint: editLabel,
      excludeSemantics: true,
      child: PressHighlight(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 11),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.ink50))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              const Icon(LucideIcons.pencil, size: 15, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
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
    final history = row.checkIn.history;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.ink50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              lead,
              IconSquare(row.icon, bg: row.bg, fg: row.color, size: 42, iconSize: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    _TimeMeta(time: row.time),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ValueText(row: row),
              trail,
            ],
          ),
          // Under the label, past the icon (design: paddingInlineStart 66).
          if (history.isAttributed)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 52, top: 4),
              child: EntryAttributionChip(history: history),
            ),
        ],
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText({required this.row});
  final _Reading row;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: row.value, style: Typo.num(weight: FontWeight.w700)),
            if (row.unit.isNotEmpty)
              TextSpan(
                text: ' ${row.unit}',
                style: Typo.num(size: FontSizes.meta, weight: FontWeight.w500, color: AppColors.textHint),
              ),
          ],
        ),
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
      TextSpan(
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 5),
              child: Icon(LucideIcons.clock, size: 12, color: AppColors.textTertiary),
            ),
          ),
          TextSpan(text: time),
        ],
      ),
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
      child: Column(
        children: [
          const Icon(LucideIcons.calendarX, size: 28, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// The check-ins of [all] recorded on [day] (local time), oldest first.
List<CheckIn> checkInsOnDay(Iterable<CheckIn> all, DateTime day) {
  bool sameDay(CheckIn ci) {
    final l = ci.recordedAt.toLocal();
    return l.year == day.year && l.month == day.month && l.day == day.day;
  }

  return all.where(sameDay).toList()..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
}
