import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../pregnancy/pregnancy_kit.dart' show fieldDecoration;
import '../profile_subscreens.dart' show memberHealthProfileProvider;
import 'family_kit.dart';
import 'medical_summary_draft.dart';

/// Opens member [m]'s medical profile (mother-child.jsx `MCMedicalScreen`).
Future<void> openMemberMedical(BuildContext context, FamilyMember m) =>
    pushFamilyScreen<void>(context, (_) => MemberMedicalScreen(id: m.id));

/// A family member's medical profile: blood type, allergies and long-term
/// conditions, which show on their emergency card. Editable while you manage
/// the profile (it is open); read-only otherwise. Saved as one form.
class MemberMedicalScreen extends ConsumerStatefulWidget {
  const MemberMedicalScreen({required this.id, super.key});
  final HealthProfileId id;
  @override
  ConsumerState<MemberMedicalScreen> createState() => _MemberMedicalScreenState();
}

class _MemberMedicalScreenState extends ConsumerState<MemberMedicalScreen> {
  late final MedicalSummaryKey _key = (form: Object(), id: widget.id);
  bool _saving = false;
  bool _saved = false;

  Future<void> _save() async {
    final user = ref.read(currentUserIdProvider);
    final draft = ref.read(medicalSummaryDraftProvider(_key));
    if (user == null || draft == null || _saving) return;
    setState(() => _saving = true);
    // The container outlives this screen: the member's card behind it must
    // refresh even if the form closed while saving.
    final container = ProviderScope.containerOf(context, listen: false);
    final r = await ref.read(saveMedicalSummaryUseCaseProvider).execute(
          userId: user,
          profileId: widget.id,
          bloodType: draft.blood,
          allergies: draft.allergies,
          conditions: draft.conditions,
        );
    container.invalidate(memberHealthProfileProvider(widget.id));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = r.isSuccess;
    });
    if (r.isFailure) {
      final s = AppScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final m =
        (ref.watch(familyMembersProvider).value ?? const <FamilyMember>[]).where((x) => x.id == widget.id).firstOrNull;
    final seeded = ref.watch(medicalSummaryDraftProvider(_key).select((d) => d != null));
    if (m == null || !seeded) return const Scaffold(backgroundColor: AppColors.white);
    final editable = m.status == ProfileStatus.active;

    return FamilyScaffold(
      title: f.tile_medical,
      footer: editable
          ? PButton(
              _saved ? s.strings.profile.pd_saved : f.save,
              icon: _saved ? LucideIcons.check : null,
              large: true,
              block: true,
              accent: s.accent,
              ar: s.rtl,
              onTap: _saving ? null : _save,
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(f.medical_intro(m.shortName), style: Typo.bodySm(ar: s.rtl)),
        ),
        _Head(icon: LucideIcons.droplet, label: f.f_blood),
        _BloodField(draftKey: _key, editable: editable),
        _Head(icon: LucideIcons.shieldAlert, label: f.card_allergies),
        _AllergiesField(draftKey: _key, editable: editable),
        _Head(icon: LucideIcons.heartPulse, label: f.medical_conditions),
        _ConditionsField(draftKey: _key, editable: editable),
        if (!editable)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                const Icon(LucideIcons.lock, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(child: Text(f.medical_locked, style: Typo.meta(ar: s.rtl))),
              ],
            ),
          ),
      ],
    );
  }
}

/// The member's blood type; none picked is "not sure".
class _BloodField extends ConsumerWidget {
  const _BloodField({required this.draftKey, required this.editable});
  final MedicalSummaryKey draftKey;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blood = ref.watch(medicalSummaryDraftProvider(draftKey).select((d) => d?.blood));
    return BloodTypeGrid(
      value: blood,
      unsure: blood == null,
      enabled: editable,
      onChanged: (b) => ref.read(medicalSummaryDraftProvider(draftKey).notifier).setBlood(b),
    );
  }
}

class _AllergiesField extends ConsumerWidget {
  const _AllergiesField({required this.draftKey, required this.editable});
  final MedicalSummaryKey draftKey;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final items = ref.watch(medicalSummaryDraftProvider(draftKey).select((d) => d?.allergies)) ?? const [];
    return ChipListCard(
      items: items,
      onChanged: editable ? (v) => ref.read(medicalSummaryDraftProvider(draftKey).notifier).setAllergies(v) : null,
      none: f.medical_allergies_none,
      addHint: f.medical_allergy_ph(s.gender),
      bg: AppColors.dangerBackground,
      fg: AppColors.danger,
    );
  }
}

class _ConditionsField extends ConsumerWidget {
  const _ConditionsField({required this.draftKey, required this.editable});
  final MedicalSummaryKey draftKey;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final items = ref.watch(medicalSummaryDraftProvider(draftKey).select((d) => d?.conditions)) ?? const [];
    return ChipListCard(
      items: items,
      onChanged: editable ? (v) => ref.read(medicalSummaryDraftProvider(draftKey).notifier).setConditions(v) : null,
      none: f.medical_conditions_none,
      addHint: f.medical_condition_ph(s.gender),
      bg: AppColors.hueViolet50,
      fg: AppColors.hueViolet,
    );
  }
}

/// A section heading with an accent icon (the design's `H`).
class _Head extends StatelessWidget {
  const _Head({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: s.accent.main),
          const SizedBox(width: 8),
          Text(
            label,
            style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// `MCChipList` — names as removable chips, and a field to add one. Without
/// [onChanged] the chips only show. A name already listed is not added twice.
class ChipListCard extends StatefulWidget {
  const ChipListCard({
    required this.items,
    required this.onChanged,
    required this.none,
    required this.addHint,
    required this.bg,
    required this.fg,
    super.key,
  });
  final List<String> items;
  final ValueChanged<List<String>>? onChanged;
  final String none;
  final String addHint;
  final Color bg;
  final Color fg;

  @override
  State<ChipListCard> createState() => _ChipListCardState();
}

class _ChipListCardState extends State<ChipListCard> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final v = _input.text.trim();
    final change = widget.onChanged;
    if (v.isEmpty || change == null) return;
    if (!widget.items.any((x) => x.toLowerCase() == v.toLowerCase())) change([...widget.items, v]);
    _input.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final change = widget.onChanged;
    return PCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.items.isEmpty) Text(widget.none, style: Typo.meta(ar: s.rtl)),
              ...widget.items.indexed.map(
                (e) => Container(
                  padding: EdgeInsetsDirectional.fromSTEB(12, 6, change == null ? 12 : 6, 6),
                  decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.$2, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: widget.fg)),
                      if (change != null) ...[
                        const SizedBox(width: 6),
                        Semantics(
                          button: true,
                          label: f.medical_remove(e.$2),
                          child: Pressable(
                            onTap: () => change([...widget.items]..removeAt(e.$1)),
                            child: Icon(LucideIcons.x, size: 13, color: widget.fg),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (change != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _add(),
                    decoration: fieldDecoration(s, widget.addHint).copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                RoundBtn(
                  icon: LucideIcons.plus,
                  semanticLabel: f.medical_add,
                  iconSize: 18,
                  onTap: _input.text.trim().isEmpty ? null : _add,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
