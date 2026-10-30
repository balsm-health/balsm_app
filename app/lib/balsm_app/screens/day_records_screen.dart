import 'dart:async';

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

/// One check-in's readings — mood hero, metric rows, optional symptoms card.
///
/// Port of the Claude Design `DayRecordsScreen`. Times come from the single
/// [CheckIn.recordedAt]; the domain does not store per-metric clocks, so we
/// never invent them.
///
/// Every reading is the patient's own, so each row's menu deletes it. The row
/// goes at once with an Undo toast; the edit is stored when the toast closes,
/// another reading is deleted, or the screen is left. A check-in emptied this
/// way is deleted, photo included.
class DayRecordsScreen extends ConsumerStatefulWidget {
  const DayRecordsScreen({super.key, required this.checkIn});
  final CheckIn checkIn;

  static Future<void> open(BuildContext context, CheckIn checkIn) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayRecordsScreen(checkIn: checkIn)));
  }

  @override
  ConsumerState<DayRecordsScreen> createState() => _DayRecordsScreenState();
}

/// The check-in as it was before the last delete, kept while Undo is offered.
typedef _Undo = ({CheckIn before, String label});

class _DayRecordsScreenState extends ConsumerState<DayRecordsScreen> {
  static const _undoFor = Duration(seconds: 5);

  late CheckIn _shown = widget.checkIn;
  _Undo? _undo;
  Timer? _undoTimer;

  // Read once up front: the last edit is stored from dispose, where ref is
  // no longer usable.
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
    _undoTimer?.cancel();
    if (_undo != null) _store(_shown);
    super.dispose();
  }

  void _store(CheckIn edited) {
    _saving = _saving.then((_) => _persist(edited));
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

  void _remove(CheckInMetric metric, String label) {
    _undoTimer?.cancel();
    // A second delete closes the first one's Undo, so store that one now.
    if (_undo != null) _store(_shown);
    setState(() {
      _undo = (before: _shown, label: label);
      _shown = _shown.without(metric);
    });
    _undoTimer = Timer(_undoFor, () {
      if (!mounted) return;
      _store(_shown);
      setState(() => _undo = null);
    });
  }

  void _restore() {
    final undo = _undo;
    if (undo == null) return;
    _undoTimer?.cancel();
    setState(() {
      _shown = undo.before;
      _undo = null;
    });
  }

  Future<void> _openMenu(_Reading r, String when) async {
    final delete = await showAppSheet<bool>(context, builder: (_) => _ReadingSheet(reading: r, when: when));
    if (delete == true && mounted) _remove(r.metric, r.label);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final checkIn = _shown;
    final d = checkIn.recordedAt.toLocal();
    final v = checkIn.vitals;
    final glucose = v.glucoseFasting ?? v.glucosePostMeal ?? v.glucoseRandom;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(d));
    final day = '${d.day} ${checkInMonthShort(s, d)}';
    final when = '$day · $time';
    final mood = checkIn.mood;

    final rows = <_Reading>[
      if (v.systolic != null && v.diastolic != null)
        _Reading(
          metric: CheckInMetric.bloodPressure,
          icon: LucideIcons.activity,
          label: s.strings.profile.m_bp,
          value: '${v.systolic}/${v.diastolic}',
          unit: s.strings.checkin.unit_bp,
          color: T.hueViolet,
          bg: T.hueViolet50,
        ),
      if (glucose != null)
        _Reading(
          metric: CheckInMetric.glucose,
          icon: LucideIcons.droplet,
          label: s.strings.profile.m_glucose,
          value: '$glucose',
          unit: s.strings.checkin.unit_glu,
          color: T.hueMint600,
          bg: T.hueMint50,
        ),
      if (v.spo2 != null)
        _Reading(
          metric: CheckInMetric.spo2,
          icon: LucideIcons.wind,
          label: s.strings.profile.m_o2,
          value: '${v.spo2}',
          unit: s.strings.checkin.unit_spo2,
          color: T.hueBlue,
          bg: T.hueBlue50,
        ),
      if (v.heartRate != null)
        _Reading(
          metric: CheckInMetric.heartRate,
          icon: LucideIcons.heartPulse,
          label: s.strings.profile.m_pulse,
          value: '${v.heartRate}',
          unit: s.strings.checkin.unit_bpm,
          color: T.hueViolet,
          bg: T.hueViolet50,
        ),
      if (v.weightKg != null)
        _Reading(
          metric: CheckInMetric.weight,
          icon: LucideIcons.scale,
          label: s.strings.profile.m_weight,
          value: _weight(v.weightKg!),
          unit: s.strings.checkin.unit_kg,
          color: T.hueBlue,
          bg: T.hueBlue50,
        ),
      if (checkIn.reportsPain)
        _Reading(
          metric: CheckInMetric.pain,
          icon: LucideIcons.zap,
          label: s.strings.profile.m_pain,
          value: '${checkIn.painLevel.value}/10',
          unit: '',
          color: T.danger,
          bg: T.dangerBg,
        ),
    ];
    final moodReading = mood == null
        ? null
        : _Reading(
            metric: CheckInMetric.mood,
            icon: LucideIcons.smile,
            label: s.strings.profile.m_mood,
            value: moodLabel(s, mood.score),
            unit: '',
            color: T.fg1,
            bg: T.ink50,
          );
    final symptoms = checkIn.symptoms.isEmpty
        ? null
        : _Reading(
            metric: CheckInMetric.symptoms,
            icon: LucideIcons.stethoscope,
            label: s.strings.checkin.symptoms_n('${checkIn.symptoms.length}'),
            value: '',
            unit: '',
            color: const Color(0xFF9A6E00),
            bg: const Color(0xFFFDF5DC),
          );
    final undo = _undo;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentColumn(
        maxWidth: 720,
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PadTop(),
            AppBarRow(children: [
              RoundBtn(
                  icon: backArrow(context),
                  semanticLabel: s.strings.common.a11y_back,
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              Expanded(child: Text(day, style: Typo.heading(ar: s.rtl))),
            ]),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                if (moodReading != null)
                  Container(
                    margin: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
                    padding: const EdgeInsets.all(16),
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
                      MoodFace(level: mood!.score, size: 40, color: moodColors[mood.score - 1]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(moodReading.value,
                              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                          const SizedBox(height: 2),
                          _TimeMeta(time: time, prefix: '${moodReading.label} · '),
                        ]),
                      ),
                      _MoreBtn(reading: moodReading, onTap: () => _openMenu(moodReading, when)),
                    ]),
                  ),
                if (rows.isNotEmpty)
                  PCard(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: rows.indexed
                          .map((e) => _MetricLine(
                                row: e.$2,
                                last: e.$1 == rows.length - 1,
                                time: time,
                                onMore: () => _openMenu(e.$2, when),
                              ))
                          .toList(),
                    ),
                  ),
                if (symptoms != null)
                  PCard(
                    margin: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 6, 13),
                    child: Row(children: [
                      IconSquare(symptoms.icon,
                          bg: symptoms.bg, fg: symptoms.color, size: 38, iconSize: 19, radius: T.rMd),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(symptoms.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                          const SizedBox(height: 2),
                          _TimeMeta(time: time),
                        ]),
                      ),
                      _MoreBtn(reading: symptoms, onTap: () => _openMenu(symptoms, when)),
                    ]),
                  ),
                // Where it hurt — the body map as the patient marked it.
                if (checkIn.painSites.isNotEmpty)
                  PCard(
                    margin: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(s.strings.checkin.body_marked,
                          style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                      const SizedBox(height: 12),
                      BodyMapPreview(sites: checkIn.painSites),
                    ]),
                  ),
                // The check-in's photo (records-vault back-reference) — design
                // DayRecordsScreen renders attachments inline with the readings.
                if (checkIn.photoRecordId != null && !checkIn.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
                    child: RecordAttachmentThumb(recordId: checkIn.photoRecordId!, height: 160),
                  ),
                if (checkIn.isEmpty) _EmptyDay(text: s.strings.checkin.day_empty),
                // Room for the Undo toast over the last row.
                const SizedBox(height: 96),
              ]),
            ),
          ]),
          if (undo != null)
            PositionedDirectional(
              start: 16,
              end: 16,
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
              child: _UndoToast(
                text: s.strings.checkin.rec_deleted(undo.label),
                action: s.strings.common.undo,
                onUndo: _restore,
              ),
            ),
        ]),
      ),
    );
  }

  static String _weight(double kg) => kg == kg.roundToDouble() ? '${kg.round()}' : kg.toStringAsFixed(1);
}

/// One deletable reading as the day screen shows it.
class _Reading {
  const _Reading({
    required this.metric,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.bg,
  });
  final CheckInMetric metric;
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color bg;
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.row, required this.last, required this.time, required this.onMore});
  final _Reading row;
  final bool last;
  final String time;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 8, 14),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink50))),
      child: Row(children: [
        IconSquare(row.icon, bg: row.bg, fg: row.color, size: 42, iconSize: 20, radius: T.rMd),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(height: 2),
            _TimeMeta(time: time),
          ]),
        ),
        const SizedBox(width: 10),
        _ValueText(row: row),
        _MoreBtn(reading: row, onTap: onMore),
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

/// The row's `⋮` (design `More`): opens the reading's actions.
class _MoreBtn extends StatelessWidget {
  const _MoreBtn({required this.reading, required this.onTap});
  final _Reading reading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RoundBtn(
        icon: LucideIcons.ellipsisVertical,
        semanticLabel: AppScope.of(context).strings.checkin.rec_more(reading.label),
        ghost: true,
        iconSize: 18,
        fg: T.fg3,
        onTap: onTap,
      );
}

/// The reading's action sheet: its name, when and what it was, and delete.
/// Pops `true` to delete.
class _ReadingSheet extends StatelessWidget {
  const _ReadingSheet({required this.reading, required this.when});
  final _Reading reading;
  final String when;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final value = [reading.value, reading.unit].where((x) => x.isNotEmpty).join(' ');
    return Container(
      decoration:
          const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      padding: EdgeInsetsDirectional.fromSTEB(20, 10, 20, sheetBottomInset(context, base: 32)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Center(child: SheetGrab()),
        const SizedBox(height: 6),
        Text(reading.label, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
        const SizedBox(height: 2),
        Text(value.isEmpty ? when : '$when · $value', style: Typo.meta(ar: s.rtl)),
        const SizedBox(height: 16),
        PButton(s.strings.checkin.rec_delete,
            icon: LucideIcons.trash2,
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

/// Design's dark Undo toast, announced to screen readers as it appears.
class _UndoToast extends StatelessWidget {
  const _UndoToast({required this.text, required this.action, required this.onUndo});
  final String text;
  final String action;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final label = Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: Colors.white);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
        decoration: BoxDecoration(color: T.ink800, borderRadius: BorderRadius.circular(T.rLg), boxShadow: T.shadowLg),
        child: Row(children: [
          const Icon(LucideIcons.trash2, size: 17, color: Color(0xD9FFFFFF)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: label)),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: const Color(0x24FFFFFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rMd)),
            ),
            child: Text(action, style: label.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
