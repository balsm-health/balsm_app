import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

import '../app_state.dart';
import '../i18n/strings.i69n.dart';
import '../kit.dart';
import '../widgets/body_map.dart';
import '../widgets/date_time_row.dart';
import '../widgets/num_pad.dart';
import '../widgets/photo_attach.dart';
import 'checkin_shared.dart';
import 'metric_drafts.dart';

// Fits the swatch label on one line under its 44pt swatch.
const _swatchLabelFontSize = 10.5;
// The live reading, the largest figure in the app.
const _liveReadingFontSize = 64.0;

/// How a metric capture is hosted.
enum MetricLogHost {
  /// Quick-log sheet: note, then Save and Cancel. [MetricLog.onSave] fires
  /// on Save; the sheet header's ✓ reads [MetricLog.onChanged] instead.
  standalone,

  /// Full check-in step: same capture + note, no Save. Wizard footer continues.
  /// [MetricLog.onChanged] fires on every edit.
  embedded,
}

/// What a metric template currently holds. PHI — never log these values.
class MetricLogCapture {
  const MetricLogCapture({
    this.summary = '',
    this.note,
    this.mood,
    this.painLevel = PainLevel.none,
    this.painSites = const {},
    this.symptoms = const {},
    this.symptomDetails = const {},
    this.vitals = Vitals.empty,
    this.when,
    this.photoBytes,
  });

  final String summary;
  final String? note;
  final Mood? mood;
  final PainLevel painLevel;
  final Set<PainSite> painSites;
  final Set<SymptomId> symptoms;

  /// Per-symptom observations (`quicklog.jsx` QuickSymptomDetail). Sparse.
  final Map<SymptomId, SymptomDetail> symptomDetails;

  final Vitals vitals;
  final DateTime? when;

  /// Local preview bytes for a note photo. Never log these.
  final List<int>? photoBytes;

  @override
  bool operator ==(Object other) =>
      other is MetricLogCapture &&
      other.summary == summary &&
      other.note == note &&
      other.mood == mood &&
      other.painLevel == painLevel &&
      other.vitals == vitals &&
      _sameSet(other.painSites, painSites) &&
      _sameSet(other.symptoms, symptoms);

  @override
  int get hashCode => Object.hash(
        summary,
        note,
        mood,
        painLevel,
        vitals,
        Object.hashAllUnordered(painSites),
        Object.hashAllUnordered(symptoms),
      );
}

bool _sameSet<E>(Set<E> a, Set<E> b) => a.length == b.length && a.containsAll(b);

typedef MetricLogSave = void Function(MetricLogCapture capture);
typedef MetricLogChanged = void Function(MetricLogCapture capture, {required bool valid});

/// Gender from the signed-in user's current profile. Profile details remain
/// ephemeral and are never logged or copied into metric captures.
class _CurrentProfileBodyMap extends ConsumerWidget {
  const _CurrentProfileBodyMap({
    required this.s,
    required this.selected,
    required this.onToggle,
  });

  final PatientAppState s;
  final Set<PainSite> selected;
  final ValueChanged<PainSite> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gender = ref.watch(currentProfileGenderProvider).value ?? s.gender;
    return BodyMap(
      gender: gender,
      selected: selected,
      onToggle: onToggle,
    );
  }
}

/// The one-metric log template for [metric]. Same UI in the quick-log sheet
/// and as a full check-in step.
class MetricLog extends StatelessWidget {
  const MetricLog({
    required this.metric,
    required this.s,
    required this.host,
    super.key,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.focusedSymptom,
    this.belowField,
    this.initial,
    this.subject,
  });

  final CheckInMetric metric;

  /// Gender of the family member being logged for (from their [Sex]); null
  /// for the account holder. Copy that describes that person follows it.
  final Gender? subject;
  final PatientAppState s;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;

  /// Quick-log one-symptom detail: skip the multi-select picker and capture
  /// just this catalog entry (body map only when the design marks it located).
  final SymptomId? focusedSymptom;

  /// Passed straight through to the metric's chrome — see
  /// [_MetricLogState.belowField].
  final Widget? belowField;

  @override
  Widget build(BuildContext context) {
    if (focusedSymptom case final focusedSymptom?) {
      return _OneSymptomLog(
        s: s,
        host: host,
        belowField: belowField,
        symptom: focusedSymptom,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    if (metric == CheckInMetric.mood) {
      return _MoodLog(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
        subject: subject,
      );
    }
    if (metric == CheckInMetric.bloodPressure) {
      return _BpLog(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    if (metric == CheckInMetric.glucose) {
      return _GlucoseLog(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    if (metric == CheckInMetric.weight) {
      return _WeightLog(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    if (metric == CheckInMetric.spo2) {
      return _O2Log(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    if (metric == CheckInMetric.heartRate) {
      return _PulseLog(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    if (metric == CheckInMetric.pain) {
      return _PainLog(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    if (metric == CheckInMetric.symptoms) {
      return _SymptomsLog(
        s: s,
        host: host,
        belowField: belowField,
        onSave: onSave,
        onCancel: onCancel,
        onChanged: onChanged,
        initial: initial,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Symptoms the design pairs with the body map (`loc: true`). Derived from the
/// catalog so the screen and the domain cannot disagree — they did while
/// tingling and itching were missing from [SymptomId] entirely.
final Set<String> _locatedSymptomIds = {
  for (final s in SymptomId.catalog)
    if (s.hasLocation) s.id,
};

mixin _MetricLogState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  PatientAppState get s;
  MetricLogHost get host;
  MetricLogSave? get onSave;
  VoidCallback? get onCancel;
  MetricLogChanged? get onChanged;
  bool get valid;
  MetricLogCapture get capture;

  /// The stored entry the form opened on, when editing one.
  MetricLogCapture? get initial;

  /// Rendered between the field and the date/time group. The full check-in
  /// puts its "I didn't measure this today" row here (report.jsx).
  Widget? get belowField => null;

  /// One token per open form, so two forms never share a draft.
  final Object _form = Object();

  /// The key every draft provider of this form is read with.
  DraftKey get draftKey => (form: _form, initial: initial?.vitals);

  // Built once: the photo in it has identity equality, so a fresh one per read
  // would be a different provider every time.
  late final ExtrasKey _extrasKey = (
    form: _form,
    when: initial?.when,
    photo: switch (initial?.photoBytes) {
      final bytes? => PickedAttach(kind: 'image', bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes)),
      _ => null,
    },
  );

  /// The form's own draft provider, when it has one; a change re-reports the capture.
  ProviderListenable<Object?>? get draft => null;

  @override
  void initState() {
    super.initState();
    // Listening keeps the auto-dispose drafts alive for as long as the form is.
    ref.listenManual(entryExtrasProvider(_extrasKey), (_, __) => emit());
    if (draft case final d?) ref.listenManual(d, (_, __) => emit());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onChanged?.call(capture, valid: valid);
    });
  }

  void emit() {
    onChanged?.call(capture, valid: valid);
  }

  Widget chrome({required Widget child}) {
    // report.jsx cards only the numeric-vital steps (`.card.card-pad` around
    // BPField / GlucoseField) — mood, pain and symptoms stay bare on the flow
    // surface, and a card there squeezed the mood tiles into an overflow.
    // Those are exactly the steps that carry a skip row, so the two travel
    // together rather than needing a second flag.
    final field = belowField == null
        ? child
        : PCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        if (belowField case final belowField?) belowField,
        DateTimeWhen(
          when: ref.watch(entryExtrasProvider(_extrasKey)).when,
          onChanged: (v) => ref.read(entryExtrasProvider(_extrasKey).notifier).setWhen(v),
        ),
        if (host == MetricLogHost.standalone) ...[
          _NoteField(
            s: s,
            controller: noteCtrl,
            photo: ref.watch(entryExtrasProvider(_extrasKey)).photo,
            onPhoto: (p) {
              // The picker answers after an await; the form may be closed by then.
              if (!mounted) return;
              ref.read(entryExtrasProvider(_extrasKey).notifier).setPhoto(p);
            },
          ),
          _FlowSubmit(s: s, valid: valid, onSave: () => onSave?.call(capture), onCancel: onCancel),
        ],
      ],
    );
  }

  DateTime get when => ref.read(entryExtrasProvider(_extrasKey)).when;
  PickedAttach? get photo => ref.read(entryExtrasProvider(_extrasKey)).photo;
  TextEditingController get noteCtrl;
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.s, required this.controller, required this.photo, required this.onPhoto});
  final PatientAppState s;
  final TextEditingController controller;
  final PickedAttach? photo;
  final ValueChanged<PickedAttach?> onPhoto;
  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `NoteAttach` opens with a rule — it closes the metric block above it.
        const Padding(padding: EdgeInsets.only(top: 18), child: Divider(height: 1, color: AppColors.ink100)),
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            s.strings.checkin.note_lbl,
            style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
          ),
        ),
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          textDirection: s.dir,
          style: Typo.body(ar: ar).copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: s.strings.checkin.note_ph(s.gender),
            hintStyle: Typo.body(ar: ar).copyWith(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide(color: s.accent.main, width: 1.5),
            ),
          ),
        ),
        NotePhotoAttach(photo: photo, onChanged: onPhoto),
      ],
    );
  }
}

/// quicklog.jsx `FlowSubmit` — Save, a hint while it is disabled, then
/// Cancel. The sheet header repeats Save as a ✓.
class _FlowSubmit extends StatelessWidget {
  const _FlowSubmit({required this.s, required this.valid, required this.onSave, required this.onCancel});
  final PatientAppState s;
  final bool valid;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: valid ? 1 : 0.4,
            child: PButton(
              s.strings.checkin.ql_save,
              large: true,
              block: true,
              accent: s.accent,
              ar: ar,
              onTap: valid ? onSave : null,
            ),
          ),
          if (!valid)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Text(
                s.strings.checkin.ql_save_hint(s.gender),
                textAlign: TextAlign.center,
                style: Typo.meta(ar: ar).copyWith(color: AppColors.textTertiary),
              ),
            ),
          const SizedBox(height: 10),
          PButton(
            s.strings.common.cancel,
            variant: BtnVariant.ghost,
            large: true,
            block: true,
            accent: s.accent,
            ar: ar,
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}

class _BigReading extends StatelessWidget {
  const _BigReading({required this.value, required this.s, this.active = true, this.onTap, this.width = 108});
  final String value;
  final PatientAppState s;
  final bool active;
  final VoidCallback? onTap;
  final double width;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: onTap == null ? 1 : 0.98,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.bg : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            // `.vital-num` carries a transparent 1.5px border at rest so the
            // box does not jump when the accent border appears.
            border: Border.all(color: active ? s.accent.main : Colors.transparent, width: 1.5),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: Typo.num(size: FontSizes.hero, color: value.isEmpty ? AppColors.ink300 : AppColors.textPrimary),
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.s, required this.onTap});
  final String label;
  final bool selected;
  final PatientAppState s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? s.accent.bg : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? s.accent.main : AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: Typo.bodySm(ar: s.rtl)
                .copyWith(fontWeight: FontWeight.w600, color: selected ? s.accent.d : AppColors.textSecondary),
          ),
        ),
      );
}

String? _trimmedNote(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : t;
}

// ── Mood ─────────────────────────────────────────────────────

class _MoodLog extends ConsumerStatefulWidget {
  const _MoodLog({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
    this.subject,
  });
  final PatientAppState s;
  final Gender? subject;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_MoodLog> createState() => _MoodLogState();
}

class _MoodLogState extends ConsumerState<_MoodLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  late int mood = widget.initial?.mood?.score ?? 0;

  @override
  bool get valid => mood > 0;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: mood > 0 ? moodLabel(s, mood, subject: widget.subject) : '',
        note: _trimmedNote(noteCtrl),
        mood: mood > 0 ? Mood(mood) : null,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => chrome(
        // Gaps between the cells, not padding inside them: padding on one
        // side left the first four 10dp narrower than the last.
        child: Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: MoodCell(
                  lv: i + 1,
                  selected: mood == i + 1,
                  s: s,
                  subject: widget.subject,
                  onTap: () => setState(() {
                    mood = i + 1;
                    emit();
                  }),
                ),
              ),
            ],
          ],
        ),
      );
}

// ── Blood pressure ───────────────────────────────────────────

class _BpLog extends ConsumerStatefulWidget {
  const _BpLog({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_BpLog> createState() => _BpLogState();
}

class _BpLogState extends ConsumerState<_BpLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  @override
  ProviderListenable<Object?> get draft => bpDraftProvider(draftKey);

  BpDraft get _bp => ref.read(bpDraftProvider(draftKey));
  BpDraftNotifier get _bpNotifier => ref.read(bpDraftProvider(draftKey).notifier);

  @override
  bool get valid => _bp.valid;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid
            ? s.strings.checkin.reading_unit(s.strings.checkin.bp_pair(_bp.sys, _bp.dia), s.strings.checkin.unit_bp)
            : '',
        note: _trimmedNote(noteCtrl),
        vitals: _bp.vitals,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    final bp = ref.watch(bpDraftProvider(draftKey));
    final sys = bp.sys;
    final dia = bp.dia;
    final onSys = bp.onSys;
    return chrome(
      child: Column(
        children: [
          // Blood pressure is written systolic/diastolic left to right in every
          // language ("120/80", as Home and Trends show it). Mirrored under RTL
          // the entry read "80 / 120"; the boxes and their labels stay LTR.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              _BigReading(value: sys, s: s, active: onSys, onTap: () => _bpNotifier.focus(systolic: true)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: Typo.subhead(ar: s.rtl)
                      .copyWith(fontSize: FontSizes.display, fontWeight: FontWeight.w700, color: AppColors.ink300),
                ),
              ),
              _BigReading(value: dia, s: s, active: !onSys, onTap: () => _bpNotifier.focus(systolic: false)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              Text(
                s.strings.checkin.sys,
                style: Typo.meta(ar: ar)
                    .copyWith(fontWeight: FontWeight.w600, color: onSys ? s.accent.main : AppColors.textTertiary),
              ),
              const SizedBox(width: 60),
              Text(
                s.strings.checkin.dia,
                style: Typo.meta(ar: ar)
                    .copyWith(fontWeight: FontWeight.w600, color: onSys ? AppColors.textTertiary : s.accent.main),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.strings.checkin.unit_bp,
            style: Typo.bodySm(ar: ar)
                .copyWith(fontSize: FontSizes.body, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          NumPad(onKey: _bpNotifier.key, onBack: _bpNotifier.back),
        ],
      ),
    );
  }
}

// ── Glucose ──────────────────────────────────────────────────

class _GlucoseLog extends ConsumerStatefulWidget {
  const _GlucoseLog({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_GlucoseLog> createState() => _GlucoseLogState();
}

class _GlucoseLogState extends ConsumerState<_GlucoseLog> with _MetricLogState {
  static const List<GlucoseContext> _contexts = GlucoseContext.values;

  @override
  PatientAppState get s => widget.s;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  @override
  ProviderListenable<Object?> get draft => glucoseDraftProvider(draftKey);

  GlucoseDraft get _glu => ref.read(glucoseDraftProvider(draftKey));
  GlucoseDraftNotifier get _gluNotifier => ref.read(glucoseDraftProvider(draftKey).notifier);

  String _ctxLabel(GlucoseContext c) => switch (c) {
        GlucoseContext.fasting => s.strings.checkin.glu_fast,
        GlucoseContext.postMeal => s.strings.checkin.glu_meal,
        GlucoseContext.random => s.strings.checkin.glu_random,
      };

  @override
  bool get valid => _glu.valid;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid
            ? s.strings.checkin.reading_unit_ctx(_glu.digits, s.strings.checkin.unit_glu, _ctxLabel(_glu.context))
            : '',
        note: _trimmedNote(noteCtrl),
        vitals: _glu.vitals,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glu = ref.watch(glucoseDraftProvider(draftKey));
    return chrome(
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _contexts
                .map(
                  (c) => _Chip(
                    label: _ctxLabel(c),
                    selected: glu.context == c,
                    s: s,
                    onTap: () => _gluNotifier.setContext(c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _BigReading(value: glu.digits, s: s, width: 150),
          const SizedBox(height: 8),
          Text(
            s.strings.checkin.unit_glu,
            style: Typo.bodySm(ar: s.rtl)
                .copyWith(fontSize: FontSizes.body, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          NumPad(onKey: _gluNotifier.key, onBack: _gluNotifier.back),
        ],
      ),
    );
  }
}

// ── Weight ───────────────────────────────────────────────────

class _WeightLog extends ConsumerStatefulWidget {
  const _WeightLog({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_WeightLog> createState() => _WeightLogState();
}

class _WeightLogState extends ConsumerState<_WeightLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  @override
  ProviderListenable<Object?> get draft => weightDraftProvider(draftKey);

  WeightDraft get _w => ref.read(weightDraftProvider(draftKey));
  WeightDraftNotifier get _wNotifier => ref.read(weightDraftProvider(draftKey).notifier);

  @override
  bool get valid => _w.valid;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid ? s.strings.checkin.reading_unit(_w.display, s.strings.profile.pd_kg) : '',
        note: _trimmedNote(noteCtrl),
        vitals: _w.vitals,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(weightDraftProvider(draftKey));
    return chrome(
      child: Column(
        children: [
          _BigReading(value: w.display, s: s, width: 170),
          const SizedBox(height: 8),
          Text(
            s.strings.profile.pd_kg,
            style: Typo.bodySm(ar: s.rtl)
                .copyWith(fontSize: FontSizes.body, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          NumPad(onKey: _wNotifier.key, onBack: _wNotifier.back, decimal: true, onDot: _wNotifier.dot),
        ],
      ),
    );
  }
}

// ── SpO₂ ─────────────────────────────────────────────────────

class _O2Log extends ConsumerStatefulWidget {
  const _O2Log({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_O2Log> createState() => _O2LogState();
}

class _O2LogState extends ConsumerState<_O2Log> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  @override
  ProviderListenable<Object?> get draft => spo2DraftProvider(draftKey);

  Spo2Draft get _o2 => ref.read(spo2DraftProvider(draftKey));
  Spo2DraftNotifier get _o2Notifier => ref.read(spo2DraftProvider(draftKey).notifier);

  @override
  bool get valid => _o2.valid;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid ? '${_o2.digits}${s.strings.checkin.unit_spo2}' : '',
        note: _trimmedNote(noteCtrl),
        vitals: _o2.vitals,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o2 = ref.watch(spo2DraftProvider(draftKey));
    return chrome(
      child: Column(
        children: [
          _BigReading(value: o2.digits, s: s, width: 150),
          const SizedBox(height: 8),
          Text(
            s.strings.checkin.unit_spo2,
            style: Typo.bodySm(ar: s.rtl)
                .copyWith(fontSize: FontSizes.body, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          NumPad(onKey: _o2Notifier.key, onBack: _o2Notifier.back),
        ],
      ),
    );
  }
}

// ── Pulse ────────────────────────────────────────────────────

/// quicklog.jsx `QuickPulse` — type the rate in bpm, or "Count with me": tap
/// each beat for [kPulseCountSeconds] seconds and the rate is the count × 4.
class _PulseLog extends ConsumerStatefulWidget {
  const _PulseLog({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_PulseLog> createState() => _PulseLogState();
}

class _PulseLogState extends ConsumerState<_PulseLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  @override
  ProviderListenable<Object?> get draft => pulseDraftProvider(draftKey);

  PulseDraft get _p => ref.read(pulseDraftProvider(draftKey));
  PulseDraftNotifier get _pNotifier => ref.read(pulseDraftProvider(draftKey).notifier);

  /// Drives the once-a-second countdown. The clock is view plumbing; the count
  /// itself lives in the draft.
  Timer? _tick;

  /// A rate outside [VitalLimits]'s range is a mistyped digit.
  @override
  bool get valid => _p.valid;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid ? s.strings.checkin.reading_unit(_p.digits, s.strings.checkin.unit_bpm) : '',
        note: _trimmedNote(noteCtrl),
        vitals: _p.vitals,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    _tick?.cancel();
    noteCtrl.dispose();
    super.dispose();
  }

  void _startCounting() {
    _tick?.cancel();
    _pNotifier.startCounting();
  }

  void _typeInstead() {
    _tick?.cancel();
    _pNotifier.typeInstead();
  }

  /// The first tap starts the clock and is itself the first beat.
  void _beat() {
    final starting = _p.left == null;
    _pNotifier.beat();
    if (starting) _tick = Timer.periodic(const Duration(seconds: 1), (_) => _second());
  }

  void _second() {
    if (!mounted) return;
    _pNotifier.tick();
    if (!_p.counting) _tick?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final c = s.strings.checkin;
    final ar = s.rtl;
    final p = ref.watch(pulseDraftProvider(draftKey));
    final digits = p.digits;
    final beats = p.beats;
    final left = p.left;
    if (!p.counting) {
      return chrome(
        child: Column(
          children: [
            _BigReading(value: digits, s: s, width: 150),
            const SizedBox(height: 8),
            Text(
              c.unit_bpm,
              style: Typo.bodySm(ar: ar)
                  .copyWith(fontSize: FontSizes.body, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4, bottom: 12),
              child: PButton(
                c.pulse_count,
                icon: LucideIcons.timer,
                variant: BtnVariant.secondary,
                accent: s.accent,
                ar: ar,
                onTap: _startCounting,
              ),
            ),
            NumPad(onKey: _pNotifier.key, onBack: _pNotifier.back),
          ],
        ),
      );
    }
    final running = left != null;
    final progress = running ? (kPulseCountSeconds - left!) / kPulseCountSeconds : 0.0;
    return chrome(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 4, bottom: 8),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                running ? c.pulse_keep : c.pulse_how(s.gender),
                textAlign: TextAlign.center,
                style: Typo.bodySm(ar: ar).copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              button: true,
              label: c.pulse_beat,
              child: Pressable(
                onTap: _beat,
                scale: 0.97,
                child: SizedBox.square(
                  dimension: 196,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(decoration: const BoxDecoration(color: AppColors.hueViolet50, shape: BoxShape.circle)),
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: const Duration(seconds: 1),
                          builder: (_, p, __) => CircularProgressIndicator(
                            value: p,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            color: AppColors.hueViolet,
                            backgroundColor: AppColors.ink100,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.heart, size: 30, color: AppColors.hueViolet),
                          const SizedBox(height: 4),
                          Text(
                            '$beats',
                            style: Typo.num(size: 44, weight: FontWeight.w800).copyWith(height: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            running ? c.pulse_left('$left') : c.pulse_start(s.gender),
                            style:
                                Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PButton(c.pulse_type, variant: BtnVariant.ghost, accent: s.accent, ar: ar, onTap: _typeInstead),
          ],
        ),
      ),
    );
  }
}

// ── Pain ─────────────────────────────────────────────────────

class _PainLog extends ConsumerStatefulWidget {
  const _PainLog({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_PainLog> createState() => _PainLogState();
}

class _PainLogState extends ConsumerState<_PainLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  late double pain = (widget.initial?.painLevel.value ?? 0).toDouble();
  late final Set<PainSite> locations = {...?widget.initial?.painSites};

  @override
  bool get valid => pain > 0 || locations.isNotEmpty;

  @override
  MetricLogCapture get capture {
    final where = locations.map((r) => siteLabel(s, r)).join(s.strings.checkin.list_sep);
    return MetricLogCapture(
      summary: where.isEmpty
          ? s.strings.checkin.pain_n('${pain.round()}')
          : s.strings.checkin.pain_n_where('${pain.round()}', where),
      note: _trimmedNote(noteCtrl),
      painLevel: PainLevel(pain.round()),
      painSites: locations,
      when: when,
      photoBytes: photo?.bytes,
    );
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    final info = painInfo(s, pain.round());
    return chrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  '${pain.round()}',
                  style: Typo.display(ar: s.rtl)
                      .copyWith(fontSize: _liveReadingFontSize, fontWeight: FontWeight.w800, color: info.color),
                ),
                Text(
                  info.lbl,
                  style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          PainSlider(
            value: pain,
            knobColor: info.color,
            onChanged: (v) => setState(() {
              pain = v;
              emit();
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              s.strings.checkin.body_location,
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
            ),
          ),
          _CurrentProfileBodyMap(
            s: s,
            selected: locations,
            onToggle: (site) => setState(() {
              if (!canToggleSite(locations, site)) return;
              locations.contains(site) ? locations.remove(site) : locations.add(site);
              emit();
            }),
          ),
        ],
      ),
    );
  }
}

// ── Symptoms ─────────────────────────────────────────────────

class _SymptomsLog extends ConsumerStatefulWidget {
  const _SymptomsLog({
    required this.s,
    required this.host,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_SymptomsLog> createState() => _SymptomsLogState();
}

class _SymptomsLogState extends ConsumerState<_SymptomsLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  final Set<SymptomId> symptoms = {};
  bool noSymptoms = false;
  final Set<PainSite> locations = {};

  /// `SymptomPicker` is `multi` in the full check-in and single-select in the
  /// one-metric quick log — the design passes `multi={false}` only there.
  bool get _multi => host == MetricLogHost.embedded;

  bool get _showMap => symptoms.any((id) => _locatedSymptomIds.contains(id.id));

  @override
  bool get valid => symptoms.isNotEmpty || noSymptoms;

  @override
  MetricLogCapture get capture {
    final label = noSymptoms
        ? s.strings.checkin.s_none
        : symptoms.map((id) => symptomLabel(s, id)).join(s.strings.checkin.list_sep);
    final where = locations.map((r) => siteLabel(s, r)).join(s.strings.checkin.list_sep);
    return MetricLogCapture(
      summary: where.isEmpty ? label : s.strings.checkin.labeled_where(label, where),
      note: _trimmedNote(noteCtrl),
      symptoms: Set.unmodifiable(symptoms),
      painSites: locations,
      when: when,
      photoBytes: photo?.bytes,
    );
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  void _select(SymptomId id) => setState(() {
        noSymptoms = false;
        if (symptoms.contains(id)) {
          symptoms.remove(id);
        } else {
          if (!_multi) symptoms.clear();
          symptoms.add(id);
        }
        if (!_showMap) locations.clear();
        emit();
      });

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return chrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `SymptomPicker` — a `.b-check-group--row`: checkboxes in the full
          // check-in, radios in the one-metric log. Not chips.
          Wrap(
            spacing: 16,
            runSpacing: 11,
            children: [
              ...symptomIcons.map(
                (e) => BCheck(
                  label: symptomLabel(s, e.$1),
                  checked: symptoms.contains(e.$1),
                  icon: e.$2,
                  radio: !_multi,
                  accent: s.accent,
                  ar: ar,
                  onTap: () => _select(e.$1),
                ),
              ),
              BCheck(
                label: s.strings.checkin.s_none,
                checked: noSymptoms,
                icon: LucideIcons.checkCircle2,
                radio: !_multi,
                accent: s.accent,
                ar: ar,
                onTap: () => setState(() {
                  noSymptoms = !noSymptoms;
                  if (noSymptoms) {
                    symptoms.clear();
                    locations.clear();
                  }
                  emit();
                }),
              ),
            ],
          ),
          if (_showMap) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                s.strings.checkin.body_location,
                style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
              ),
            ),
            _CurrentProfileBodyMap(
              s: s,
              selected: locations,
              onToggle: (site) => setState(() {
                if (!canToggleSite(locations, site)) return;
                locations.contains(site) ? locations.remove(site) : locations.add(site);
                emit();
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// One catalog symptom from the quick-log list — note + save, body map
/// only when the design marks the entry located.
class _OneSymptomLog extends ConsumerStatefulWidget {
  const _OneSymptomLog({
    required this.s,
    required this.host,
    required this.symptom,
    this.onSave,
    this.onCancel,
    this.onChanged,
    this.belowField,
    this.initial,
  });
  final PatientAppState s;
  final MetricLogHost host;
  final Widget? belowField;
  final SymptomId symptom;
  final MetricLogSave? onSave;
  final VoidCallback? onCancel;
  final MetricLogChanged? onChanged;

  /// The stored entry to open on, when editing one; null for a new entry.
  final MetricLogCapture? initial;
  @override
  ConsumerState<_OneSymptomLog> createState() => _OneSymptomLogState();
}

class _OneSymptomLogState extends ConsumerState<_OneSymptomLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  VoidCallback? get onCancel => widget.onCancel;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  MetricLogCapture? get initial => widget.initial;
  @override
  late final TextEditingController noteCtrl = TextEditingController(text: widget.initial?.note)..addListener(emit);

  late final Set<PainSite> locations = {...?widget.initial?.painSites};

  /// Only urine and stool carry one (`SymptomId.hasDetail`).
  late SymptomDetail detail = widget.initial?.symptomDetails[widget.symptom] ?? const SymptomDetail();

  bool get _showMap => _locatedSymptomIds.contains(widget.symptom.id);

  @override
  bool get valid => true;

  /// The design appends what was observed to the saved summary line.
  String _detailSuffix() {
    final c = s.strings.checkin;
    final parts = [
      if (detail.urineColor case final colour?) urineColorLabel(s, colour),
      if (detail.urineMl case final ml? when ml > 0) '$ml ${c.sd_ml}',
      if (detail.blood) c.sd_blood,
    ];
    return parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
  }

  @override
  MetricLogCapture get capture {
    final label = symptomLabel(s, widget.symptom);
    final where = locations.map((r) => siteLabel(s, r)).join(s.strings.checkin.list_sep);
    final base = where.isEmpty ? label : s.strings.checkin.labeled_where(label, where);
    return MetricLogCapture(
      summary: '$base${_detailSuffix()}',
      note: _trimmedNote(noteCtrl),
      symptoms: {widget.symptom},
      // An untouched detail is not an observation, so it is not stored.
      symptomDetails: detail.isEmpty ? const {} : {widget.symptom: detail},
      painSites: locations,
      when: when,
      photoBytes: photo?.bytes,
    );
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDetail = widget.symptom.hasDetail;
    if (!_showMap && !hasDetail) return chrome(child: const SizedBox.shrink());
    final ar = s.rtl;
    return chrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showMap) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s.strings.checkin.body_location,
                style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
              ),
            ),
            _CurrentProfileBodyMap(
              s: s,
              selected: locations,
              onToggle: (site) => setState(() {
                if (!canToggleSite(locations, site)) return;
                locations.contains(site) ? locations.remove(site) : locations.add(site);
                emit();
              }),
            ),
          ],
          if (hasDetail)
            _SymptomDetailCard(
              s: s,
              symptom: widget.symptom,
              detail: detail,
              onChanged: (d) => setState(() {
                detail = d;
                emit();
              }),
            ),
        ],
      ),
    );
  }
}

/// `.pain-track` — a 0–10 scale on a mint→sun→danger gradient rail.
///
/// Material's `Slider` can only paint a flat active track, so the rail, knob
/// and ticks are drawn directly. The rail shows the whole scale at once (it is
/// a severity legend, not a progress bar), which is why it is not split into
/// active/inactive halves.
class PainSlider extends StatelessWidget {
  const PainSlider({required this.value, required this.knobColor, required this.onChanged, super.key});

  final double value; // 0..10
  final Color knobColor;
  final ValueChanged<double> onChanged;

  static const _railHeight = 12.0;
  static const _knob = 36.0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 6),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: LayoutBuilder(
              builder: (context, c) {
                // The knob centre travels between half-knob insets so it never
                // overhangs the rail ends.
                final travel = c.maxWidth - _knob;
                void report(double dx) {
                  final raw = ((dx - _knob / 2) / travel).clamp(0.0, 1.0);
                  final t = rtl ? 1 - raw : raw;
                  onChanged((t * 10).roundToDouble());
                }

                final fraction = (rtl ? 10 - value : value) / 10;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => report(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
                  child: Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [
                      Center(
                        child: Container(
                          height: _railHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            gradient: const LinearGradient(
                              colors: [AppColors.hueMint, AppColors.sun400, AppColors.danger],
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: fraction * travel,
                        child: Container(
                          width: _knob,
                          height: _knob,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: knobColor, width: 3),
                            boxShadow: AppShadows.md,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // `.pain-ticks` — the endpoints and midpoint, in tabular figures.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final n in const [0, 5, 10])
                Text('$n', style: Typo.num(size: FontSizes.eyebrow, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}

/// `quicklog.jsx` `QuickSymptomDetail`'s urine card (colour · quantity · blood)
/// and stool card (blood).
///
/// Every control records what the patient observed and nothing more — no
/// hydration scale, no interpretation, no flag. Self-report is a journal.
class _SymptomDetailCard extends StatelessWidget {
  const _SymptomDetailCard({
    required this.s,
    required this.symptom,
    required this.detail,
    required this.onChanged,
  });

  final PatientAppState s;
  final SymptomId symptom;
  final SymptomDetail detail;
  final ValueChanged<SymptomDetail> onChanged;

  /// The design's stepper moves in 50ml steps.
  static const _step = 50;

  @override
  Widget build(BuildContext context) {
    final c = s.strings.checkin;
    final ar = s.rtl;
    return PCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (symptom.asksUrineDetail) ...[
            _Head(icon: LucideIcons.palette, label: c.sd_color, accent: s.accent.main, ar: ar),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final colour in UrineColor.values)
                  Expanded(
                    child: _Swatch(
                      s: s,
                      colour: colour,
                      selected: detail.urineColor == colour,
                      // Tapping the selected swatch clears it — nothing reported.
                      onTap: () => onChanged(
                        detail.urineColor == colour
                            ? detail.copyWith(clearUrineColor: true)
                            : detail.copyWith(urineColor: colour),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.ink100),
            const SizedBox(height: 18),
            _Head(icon: LucideIcons.beaker, label: c.sd_quantity, accent: s.accent.main, ar: ar),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepBtn(
                  icon: LucideIcons.minus,
                  // Never below zero, and stepping down from nothing stays nothing.
                  onTap: detail.urineMl == null || detail.urineMl == 0
                      ? null
                      : () => onChanged(detail.copyWith(urineMl: math.max(0, detail.urineMl! - _step))),
                ),
                const SizedBox(width: 18),
                // `min-width: 90` — a fixed width clips at three digits.
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 90),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${detail.urineMl ?? 0}',
                        textDirection: TextDirection.ltr,
                        style: Typo.num(
                          size: FontSizes.title,
                          weight: FontWeight.w700,
                          color: detail.urineMl == null ? AppColors.textHint : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        c.sd_ml,
                        style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                _StepBtn(
                  icon: LucideIcons.plus,
                  onTap: () => onChanged(detail.copyWith(urineMl: (detail.urineMl ?? 0) + _step)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.ink100),
            const SizedBox(height: 16),
          ],
          // Both urine and stool ask about blood.
          Pressable(
            onTap: () => onChanged(detail.copyWith(blood: !detail.blood)),
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: detail.blood ? AppColors.dangerBackground : AppColors.ink50,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.droplet, size: 17, color: detail.blood ? AppColors.danger : AppColors.textTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.sd_blood,
                      style: Typo.bodySm(ar: ar).copyWith(
                        fontWeight: FontWeight.w600,
                        color: detail.blood ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // The row is already the tap target, so this is the indicator
                  // only — `BCheck` would draw its own label and hit area.
                  AnimatedContainer(
                    duration: Motion.fast,
                    curve: Motion.easeOut,
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: detail.blood ? AppColors.danger : AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: detail.blood ? AppColors.danger : AppColors.borderStrong, width: 1.5),
                    ),
                    child: detail.blood ? const Icon(LucideIcons.check, size: 14, color: AppColors.white) : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.icon, required this.label, required this.accent, required this.ar});
  final IconData icon;
  final String label;
  final Color accent;
  final bool ar;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Text(label, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ],
      );
}

/// One urine colour, as a 42px disc with its label under it.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.s, required this.colour, required this.selected, required this.onTap});
  final PatientAppState s;
  final UrineColor colour;
  final bool selected;
  final VoidCallback onTap;

  String _label(CheckinStrings c) => switch (colour) {
        UrineColor.pale => c.sd_u_pale,
        UrineColor.yellow => c.sd_u_yellow,
        UrineColor.dark => c.sd_u_dark,
        UrineColor.red => c.sd_u_red,
        UrineColor.brown => c.sd_u_brown,
      };

  @override
  Widget build(BuildContext context) {
    final accent = s.accent.main;
    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: selected ? 1.06 : 1,
            duration: Motion.fast,
            curve: Motion.easeOut,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(colour.swatch),
                shape: BoxShape.circle,
                // Design: a white gap ring, then the accent ring, when selected.
                border: Border.all(color: AppColors.white, width: selected ? 2.5 : 0),
                boxShadow: [
                  BoxShadow(
                    color: selected ? accent : AppColors.hairline,
                    spreadRadius: selected ? 2 : 1,
                  ),
                ],
              ),
              child: selected
                  ? Icon(
                      LucideIcons.check,
                      size: 17,
                      // The two pale swatches need dark ink to stay legible.
                      color: colour.isLightSwatch ? AppColors.onSun : AppColors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _label(s.strings.checkin),
            textAlign: TextAlign.center,
            style: Typo.bodySm(ar: s.rtl).copyWith(
              fontSize: _swatchLabelFontSize,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: selected ? accent : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 40px +/- disc beside the quantity.
class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Pressable(
          onTap: onTap ?? () {},
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Icon(icon, size: 17, color: AppColors.textSecondary),
          ),
        ),
      );
}
