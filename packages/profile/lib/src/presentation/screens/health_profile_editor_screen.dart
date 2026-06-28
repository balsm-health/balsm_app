import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/add_allergy_use_case.dart';
import '../../application/use_cases/add_chronic_condition_use_case.dart';
import '../../application/use_cases/add_emergency_contact_use_case.dart';
import '../../application/use_cases/remove_allergy_use_case.dart';
import '../../application/use_cases/update_health_profile_use_case.dart';
import '../../domain/aggregates/health_profile.dart';
import '../../infrastructure/drift/profile_dao.dart';

/// FR-213: convert any Arabic-Indic digits (٠-٩) in [input] to Western Arabic.
/// PHI-safe: pure local transform, never logged or transmitted.
String normalizeArabicNumerals(String input) {
  return input.replaceAllMapped(
    RegExp(r'[٠-٩]'),
    (m) => (m.group(0)!.codeUnitAt(0) - 0x0660).toString(),
  );
}

/// Watches the current user's on-device [HealthProfile]. PHI stays on-device.
final _currentProfileProvider =
    StreamProvider.autoDispose<HealthProfile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream<HealthProfile?>.value(null);
  }
  return ref.watch(profileDaoProvider).watchProfile(userId);
});

/// PHI editor — blood type, allergies, chronic conditions, emergency contacts.
/// All data is on-device only (SQLCipher); nothing here is sent to the cloud.
class HealthProfileEditorScreen extends ConsumerStatefulWidget {
  const HealthProfileEditorScreen({super.key});

  @override
  ConsumerState<HealthProfileEditorScreen> createState() =>
      _HealthProfileEditorScreenState();
}

class _HealthProfileEditorScreenState
    extends ConsumerState<HealthProfileEditorScreen> {
  String? _errorMessage;

  String? get _userId => ref.read(currentUserIdProvider);

  void _showError(AppFailure failure) {
    // PHI-safe: failure.message carries validation/storage text, never PHI values.
    setState(() => _errorMessage = failure.message);
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _setBloodType(String? bloodType) async {
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

  Future<void> _removeAllergy(UuidV7 allergyId) async {
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

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          children: [
            BalsmAppBar.withBack(
              title: 'Health Profile',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const BalsmLoadingIndicator(),
                error: (e, _) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: BalsmErrorBanner(message: 'Could not load profile'),
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
    final allergies = profile?.allergies ?? const <Allergy>[];
    final conditions = profile?.conditions ?? const <ChronicCondition>[];
    final contacts = profile?.emergencyContacts ?? const <EmergencyContact>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (_errorMessage != null) ...[
          BalsmErrorBanner(message: _errorMessage!),
          const SizedBox(height: 16),
        ],

        // ---- Blood type ----
        const _SectionHeader(title: 'Blood Type'),
        const SizedBox(height: 8),
        _BloodTypeDropdown(
          value: profile?.bloodType,
          onChanged: _setBloodType,
        ),
        const SizedBox(height: 24),

        // ---- Allergies ----
        _SectionHeader(
          title: 'Allergies',
          trailing: _AddButton(onTap: _addAllergy),
        ),
        const SizedBox(height: 8),
        if (allergies.isEmpty)
          const _EmptyHint(text: 'No allergies added')
        else
          BalsmListCard(
            children: [
              for (final a in allergies)
                BalsmListRow(
                  label: a.name,
                  showChevron: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (a.isControlledSubstance)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: BalsmPill(
                            label: 'Controlled',
                            variant: BalsmPillVariant.info,
                          ),
                        ),
                      BalsmPill(
                        label: _severityLabel(a.severity),
                        variant: _severityVariant(a.severity),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: BalsmColors.fg4),
                        onPressed: () => _removeAllergy(a.id),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),

        // ---- Chronic conditions ----
        _SectionHeader(
          title: 'Chronic Conditions',
          trailing: _AddButton(onTap: _addCondition),
        ),
        const SizedBox(height: 8),
        if (conditions.isEmpty)
          const _EmptyHint(text: 'No conditions added')
        else
          BalsmListCard(
            children: [
              for (final c in conditions)
                BalsmListRow(label: c.name, showChevron: false),
            ],
          ),
        const SizedBox(height: 24),

        // ---- Emergency contacts (max 3) ----
        _SectionHeader(
          title: 'Emergency Contacts',
          trailing: contacts.length >= AddEmergencyContactUseCase.maxContacts
              ? null
              : _AddButton(onTap: _addContact),
        ),
        const SizedBox(height: 8),
        if (contacts.isEmpty)
          const _EmptyHint(text: 'No emergency contacts added')
        else
          BalsmListCard(
            children: [
              for (final c in contacts)
                BalsmListRow(
                  label: c.name,
                  sublabel: c.relation == null
                      ? c.phone
                      : '${c.relation} · ${c.phone}',
                  showChevron: false,
                  trailing: c.isPrimary
                      ? const BalsmPill(
                          label: 'Primary',
                          variant: BalsmPillVariant.info,
                        )
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  static String _severityLabel(String severity) {
    switch (severity) {
      case 'mild':
        return 'Mild';
      case 'moderate':
        return 'Moderate';
      case 'severe':
        return 'Severe';
      default:
        return severity;
    }
  }

  static BalsmPillVariant _severityVariant(String severity) {
    switch (severity) {
      case 'severe':
        return BalsmPillVariant.danger;
      case 'moderate':
        return BalsmPillVariant.warn;
      case 'mild':
      default:
        return BalsmPillVariant.neutral;
    }
  }
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
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BalsmColors.fg1,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18, color: BalsmColors.appAccent),
      label: const Text(
        'Add',
        style: TextStyle(
          color: BalsmColors.appAccent,
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
      style: const TextStyle(fontSize: 14, color: BalsmColors.fg4),
    );
  }
}

class _BloodTypeDropdown extends StatelessWidget {
  const _BloodTypeDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BalsmColors.surface,
        borderRadius: BorderRadius.circular(BalsmRadius.md),
        border: Border.all(color: BalsmColors.border, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: const Text(
            'Select blood type',
            style: TextStyle(color: BalsmColors.fg4, fontSize: 18),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: BalsmColors.fg3),
          style: const TextStyle(fontSize: 18, color: BalsmColors.fg1),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Unknown', style: TextStyle(color: BalsmColors.fg3)),
            ),
            for (final bt in kBloodTypes)
              DropdownMenuItem<String?>(value: bt, child: Text(bt)),
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

class _AddAllergySheet extends StatefulWidget {
  const _AddAllergySheet();

  @override
  State<_AddAllergySheet> createState() => _AddAllergySheetState();
}

class _AddAllergySheetState extends State<_AddAllergySheet> {
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
    return _SheetScaffold(
      title: 'Add Allergy',
      onSave: () {
        final name = _controller.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(context, _AllergyInput(name, _severity, _controlled));
      },
      children: [
        BalsmField(label: 'Allergen', controller: _controller, autofocus: true),
        const SizedBox(height: 16),
        const Text(
          'Severity',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BalsmColors.fg2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final s in kAllergySeverities)
              ChoiceChip(
                label: Text(s[0].toUpperCase() + s.substring(1)),
                selected: _severity == s,
                onSelected: (_) => setState(() => _severity = s),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Controlled substance'),
          value: _controlled,
          onChanged: (v) => setState(() => _controlled = v),
        ),
      ],
    );
  }
}

class _AddConditionSheet extends StatefulWidget {
  const _AddConditionSheet();

  @override
  State<_AddConditionSheet> createState() => _AddConditionSheetState();
}

class _AddConditionSheetState extends State<_AddConditionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Condition',
      onSave: () {
        final name = _controller.text.trim();
        if (name.isEmpty) return;
        Navigator.pop(context, name);
      },
      children: [
        BalsmField(
          label: 'Condition',
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

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
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
    return _SheetScaffold(
      title: 'Add Emergency Contact',
      onSave: () {
        final name = _nameController.text.trim();
        // FR-213: normalize Arabic-Indic digits before persisting.
        final phone = normalizeArabicNumerals(_phoneController.text).trim();
        if (name.isEmpty || phone.isEmpty) return;
        final relation = _relationController.text.trim();
        Navigator.pop(
          context,
          _ContactInput(name, phone, relation.isEmpty ? null : relation),
        );
      },
      children: [
        BalsmField(label: 'Name', controller: _nameController, autofocus: true),
        const SizedBox(height: 16),
        BalsmField.numeric(label: 'Phone', controller: _phoneController),
        const SizedBox(height: 16),
        BalsmField(label: 'Relation (optional)', controller: _relationController),
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
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BalsmColors.fg1,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 20),
          BalsmButton(label: 'Save', onPressed: onSave),
        ],
      ),
    );
  }
}
