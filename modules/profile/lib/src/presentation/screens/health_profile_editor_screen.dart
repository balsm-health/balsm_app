import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/add_allergy_use_case.dart';
import '../../application/use_cases/add_chronic_condition_use_case.dart';
import '../../application/use_cases/add_emergency_contact_use_case.dart';
import '../../application/use_cases/remove_allergy_use_case.dart';
import '../../application/use_cases/remove_chronic_condition_use_case.dart';
import '../../application/use_cases/update_health_profile_use_case.dart';
import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/allergy_severity.dart';
import '../../domain/value_objects/ids.dart';
import '../../infrastructure/drift/drift_profile_data_source.dart';
import '../i18n/i18n.dart';

/// Watches the current user's on-device [HealthProfile]. PHI stays on-device.
final StreamProvider<HealthProfile?> _currentProfileProvider = StreamProvider.autoDispose<HealthProfile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream<HealthProfile?>.value(null);
  }
  return ref.watch(profileDataSourceProvider).watchProfile(userId);
});

/// PHI editor — blood type, allergies, chronic conditions, emergency contacts.
/// All data is on-device only (SQLCipher); nothing here is sent to the cloud.
class HealthProfileEditorScreen extends ConsumerStatefulWidget {
  const HealthProfileEditorScreen({super.key});

  @override
  ConsumerState<HealthProfileEditorScreen> createState() => _HealthProfileEditorScreenState();
}

class _HealthProfileEditorScreenState extends ConsumerState<HealthProfileEditorScreen> {
  String? _errorMessage;

  UserId? get _userId => ref.read(currentUserIdProvider);

  void _showError(AppFailure failure) {
    // PHI-safe: failure.message carries validation/storage text, never PHI values.
    setState(() => _errorMessage = failure.message);
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _setBloodType(BloodType? bloodType) async {
    final userId = _userId;
    if (userId == null) return;
    _clearError();
    final result = await ref.read(updateHealthProfileUseCaseProvider).execute(
          userId: userId,
          bloodType: bloodType,
          clearBloodType: bloodType == null,
        );
    if (!result.isSuccess) _showError(result.error);
  }

  Future<void> _addAllergy() async {
    final userId = _userId;
    if (userId == null) return;
    final input = await showModalBottomSheet<_AllergyInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddAllergySheet(),
    );
    if (input == null) return;
    _clearError();
    final result = await ref.read(addAllergyUseCaseProvider).execute(
          userId: userId,
          name: input.name,
          severity: input.severity,
          isControlledSubstance: input.isControlled,
        );
    if (!result.isSuccess) _showError(result.error);
  }

  Future<void> _removeAllergy(AllergyId allergyId) async {
    final userId = _userId;
    if (userId == null) return;
    _clearError();
    final result = await ref.read(removeAllergyUseCaseProvider).execute(
          userId: userId,
          allergyId: allergyId,
        );
    if (!result.isSuccess) _showError(result.error);
  }

  Future<void> _addCondition() async {
    final userId = _userId;
    if (userId == null) return;
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddConditionSheet(),
    );
    if (name == null) return;
    _clearError();
    final result = await ref.read(addChronicConditionUseCaseProvider).execute(
          userId: userId,
          name: name,
        );
    if (!result.isSuccess) _showError(result.error);
  }

  Future<void> _removeCondition(ChronicConditionId conditionId) async {
    final userId = _userId;
    if (userId == null) return;
    _clearError();
    final result = await ref.read(removeChronicConditionUseCaseProvider).execute(
          userId: userId,
          conditionId: conditionId,
        );
    if (!result.isSuccess) _showError(result.error);
  }

  Future<void> _addContact() async {
    final userId = _userId;
    if (userId == null) return;
    final input = await showModalBottomSheet<_ContactInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddContactSheet(),
    );
    if (input == null) return;
    _clearError();
    final result = await ref.read(addEmergencyContactUseCaseProvider).execute(
          userId: userId,
          name: input.name,
          phone: input.phone,
          relation: input.relation,
        );
    if (!result.isSuccess) _showError(result.error);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_currentProfileProvider);
    final m = ref.watch(profileStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          children: [
            BalsmAppBar.withBack(
              title: m.title,
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const BalsmLoadingIndicator(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: BalsmErrorBanner(message: m.loadError),
                ),
                data: (profile) => _buildBody(context, profile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HealthProfile? profile) {
    final m = ref.watch(profileStringsProvider);
    final allergies = profile?.allergies ?? const <Allergy>[];
    final conditions = profile?.conditions ?? const <ChronicCondition>[];
    final contacts = profile?.emergencyContacts ?? const <EmergencyContact>[];

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
      children: [
        if (_errorMessage case final errorMessage?) ...[
          BalsmErrorBanner(message: errorMessage),
          const SizedBox(height: 16),
        ],

        // ---- Blood type ----
        _SectionHeader(title: m.bloodType),
        const SizedBox(height: 8),
        _BloodTypeDropdown(
          value: profile?.bloodType,
          onChanged: _setBloodType,
        ),
        const SizedBox(height: 24),

        // ---- Allergies ----
        _SectionHeader(
          title: m.allergies.label,
          trailing: _AddButton(onTap: _addAllergy),
        ),
        const SizedBox(height: 8),
        if (allergies.isEmpty)
          _EmptyHint(text: m.noAllergies)
        else
          BalsmListCard(
            children: [
              ...allergies.map(
                (a) => BalsmListRow(
                  label: a.name,
                  showChevron: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (a.isControlledSubstance)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: BalsmPill(
                            label: m.controlled,
                            variant: BalsmPillVariant.info,
                          ),
                        ),
                      BalsmPill(
                        label: _severityLabel(a.severity),
                        variant: _severityVariant(a.severity),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
                        onPressed: () => _removeAllergy(a.id),
                        tooltip: m.remove,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // ---- Chronic conditions ----
        _SectionHeader(
          title: m.chronicConditions,
          trailing: _AddButton(onTap: _addCondition),
        ),
        const SizedBox(height: 8),
        if (conditions.isEmpty)
          _EmptyHint(text: m.noConditions)
        else
          BalsmListCard(
            children: [
              ...conditions.map(
                (c) => BalsmListRow(
                  label: c.name,
                  showChevron: false,
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
                    onPressed: () => _removeCondition(c.id),
                    tooltip: m.remove,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // ---- Emergency contacts (max 3) ----
        _SectionHeader(
          title: m.contacts,
          trailing: contacts.length >= AddEmergencyContactUseCase.maxContacts ? null : _AddButton(onTap: _addContact),
        ),
        const SizedBox(height: 8),
        if (contacts.isEmpty)
          _EmptyHint(text: m.noContacts)
        else
          BalsmListCard(
            children: [
              ...contacts.map(
                (c) => BalsmListRow(
                  label: c.name,
                  sublabel: c.relation == null ? c.phone : '${c.relation} · ${c.phone}',
                  showChevron: false,
                  trailing: c.isPrimary
                      ? BalsmPill(
                          label: m.primary,
                          variant: BalsmPillVariant.info,
                        )
                      : null,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// The scale itself is domain (see [AllergySeverity]); how loud each level
  /// looks is not. An unrecognised stored value keeps its raw text and a
  /// neutral pill rather than being silently reclassified.
  static String _severityLabel(String severity) =>
      AllergySeverity.fromWire(severity)?.label(profileStrings.current) ?? severity;

  static BalsmPillVariant _severityVariant(String severity) => switch (AllergySeverity.fromWire(severity)) {
        AllergySeverity.severe => BalsmPillVariant.danger,
        AllergySeverity.moderate => BalsmPillVariant.warn,
        AllergySeverity.mild || null => BalsmPillVariant.neutral,
      };
}

// ---------------------------------------------------------------------------
// Section widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: FontSizes.body,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing case final trailing?) trailing,
      ],
    );
  }
}

class _AddButton extends ConsumerWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(profileStringsProvider);
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18, color: AppColors.hueBlue),
      label: Text(
        m.addShort,
        style: const TextStyle(
          color: AppColors.hueBlue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textHint),
    );
  }
}

class _BloodTypeDropdown extends ConsumerWidget {
  const _BloodTypeDropdown({required this.value, required this.onChanged});
  final BloodType? value;
  final ValueChanged<BloodType?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(profileStringsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BloodType?>(
          isExpanded: true,
          value: value,
          hint: Text(
            m.selectBloodType,
            style: const TextStyle(color: AppColors.textHint, fontSize: FontSizes.subhead),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textTertiary),
          style: const TextStyle(fontSize: FontSizes.subhead, color: AppColors.textPrimary),
          items: [
            DropdownMenuItem<BloodType?>(
              child: Text(m.unknown, style: const TextStyle(color: AppColors.textTertiary)),
            ),
            ...BloodType.values.map(
              (bt) => DropdownMenuItem<BloodType?>(value: bt, child: Text(bt.label)),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add sheets
// ---------------------------------------------------------------------------

class _AllergyInput {
  const _AllergyInput(this.name, this.severity, this.isControlled);
  final String name;
  final String severity;
  final bool isControlled;
}

class _AddAllergySheet extends ConsumerStatefulWidget {
  const _AddAllergySheet();

  @override
  ConsumerState<_AddAllergySheet> createState() => _AddAllergySheetState();
}

class _AddAllergySheetState extends ConsumerState<_AddAllergySheet> {
  final _controller = TextEditingController();
  String _severity = 'mild';
  bool _controlled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(profileStringsProvider);
    return _SheetScaffold(
      title: m.allergies.add,
      onSave: () {
        final name = _controller.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(context, _AllergyInput(name, _severity, _controlled));
      },
      children: [
        BalsmField(label: m.allergen, controller: _controller, autofocus: true),
        const SizedBox(height: 16),
        Text(
          m.severityLabel,
          style: const TextStyle(
            fontSize: FontSizes.bodySm,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ...kAllergySeverities.map(
              (s) => ChoiceChip(
                label: Text(AllergySeverity.fromWire(s)?.label(m) ?? s),
                selected: _severity == s,
                onSelected: (_) => setState(() => _severity = s),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(m.controlledSubstance),
          value: _controlled,
          onChanged: (v) => setState(() => _controlled = v),
        ),
      ],
    );
  }
}

class _AddConditionSheet extends ConsumerStatefulWidget {
  const _AddConditionSheet();

  @override
  ConsumerState<_AddConditionSheet> createState() => _AddConditionSheetState();
}

class _AddConditionSheetState extends ConsumerState<_AddConditionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(profileStringsProvider);
    return _SheetScaffold(
      title: m.addCondition,
      onSave: () {
        final name = _controller.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(context, name);
      },
      children: [
        BalsmField(
          label: m.condition,
          controller: _controller,
          autofocus: true,
        ),
      ],
    );
  }
}

class _ContactInput {
  const _ContactInput(this.name, this.phone, this.relation);
  final String name;
  final String phone;
  final String? relation;
}

class _AddContactSheet extends ConsumerStatefulWidget {
  const _AddContactSheet();

  @override
  ConsumerState<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<_AddContactSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(profileStringsProvider);
    return _SheetScaffold(
      title: m.addContact,
      onSave: () {
        final name = _nameController.text.trim();
        // FR-213: normalize Arabic-Indic digits before persisting.
        final phone = toWesternDigits(_phoneController.text).trim();
        if (name.isEmpty || phone.isEmpty) return;
        final relation = _relationController.text.trim();
        Navigator.pop(
          context,
          _ContactInput(name, phone, relation.isEmpty ? null : relation),
        );
      },
      children: [
        BalsmField(label: m.name, controller: _nameController, autofocus: true),
        const SizedBox(height: 16),
        BalsmField.numeric(label: m.phone, controller: _phoneController),
        const SizedBox(height: 16),
        BalsmField(label: m.relationOptional, controller: _relationController),
      ],
    );
  }
}

/// Shared bottom-sheet chrome for the add flows. RTL-aware via Directionality
/// inherited from the app; padding accounts for the keyboard inset.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.onSave,
    required this.children,
  });

  final String title;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 20,
        end: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: FontSizes.subhead,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 20),
          BalsmButton(label: coreMessagesOf(context).common.save, onPressed: onSave),
        ],
      ),
    );
  }
}
