import 'dart:async';
import 'dart:ui' as ui;

import 'package:account/account.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../auth/handle_check_controller.dart';
import '../kit.dart';
import '../qr/qr_share_controller.dart';
import '../responsive.dart';
import '../shell.dart';
import '../widgets/balsm_mark.dart';
import '../widgets/permission_denied.dart';
import '../widgets/phone_field.dart';
import 'go_online_sheet.dart';
import 'profile_edit_draft.dart';
import 'profile_screen.dart' show ProfileScreen;
import 'profile_subscreens.dart';

// An emoji flag glyph, sized to its row rather than to the text scale.
const _flagEmojiSize = 20.0;
// An emoji flag glyph in the country list, sized to its row.
const _flagEmojiSizeLarge = 22.0;

/// Opens the account/identity editor (home.jsx AccountDetailsScreen).
void openPersonalDetails(BuildContext context) {
  final s = AppScope.of(context);
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => Directionality(textDirection: s.dir, child: AdaptiveFrame(child: PersonalDetailsScreen(s: s))),
    ),
  );
}

/// Reads the current user's emergency contacts from the on-device HealthProfile
/// (SQLCipher PHI). Re-runs on sign-in/out; empty when signed out. Adding a
/// contact via AddEmergencyContactUseCase invalidates this provider.
final FutureProvider<List<EmergencyContact>> _emergencyContactsProvider =
    FutureProvider.autoDispose<List<EmergencyContact>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final profile = await ref.watch(profileDataSourceProvider).getProfile(userId);
  return profile?.emergencyContacts ?? const [];
});

/// Reads the on-device [EmergencyCardSnapshot] via the Tier-0
/// `emergencySnapshotReaderProvider` seam (the same PHI the mint use-case
/// encrypts). Used only to gate the QR-share sheet's mint affordance: `null`
/// when signed out or when there is no profile yet. Never leaves the device.
final FutureProvider<EmergencyCardSnapshot?> _emergencySnapshotProvider =
    FutureProvider.autoDispose<EmergencyCardSnapshot?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(emergencySnapshotReaderProvider).readSnapshot();
});

/// A mandatory profile field the completion card can report as missing.
enum ProfileGap { name, dateOfBirth, gender, bloodType }

/// The set of mandatory fields still missing: name, date of birth, gender
/// (account profile) and blood type (on-device health profile). Empty set =
/// complete; the card renders the set so the user knows exactly what's left.
/// Loading/offline/signed-out resolve to empty so the card never nags on a
/// guess.
final FutureProvider<Set<ProfileGap>> profileGapsProvider = FutureProvider.autoDispose<Set<ProfileGap>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  final details = await ref.watch(accountProfileUseCaseProvider).load();
  // Watch the SAME provider the medical-profile screen edits + invalidates,
  // so setting the blood type retires the card immediately instead of after
  // the next cold rebuild.
  final health = await ref.watch(healthProfileProvider.future);
  return {
    if (((details?.displayName ?? '').trim().isEmpty) && ((details?.firstName ?? '').trim().isEmpty)) ProfileGap.name,
    if ((details?.dateOfBirth ?? '').isEmpty) ProfileGap.dateOfBirth,
    if (details?.gender == null) ProfileGap.gender,
    if (health?.bloodType == null) ProfileGap.bloodType,
  };
});

/// Connected accounts (Apple / Google) on Account details. Off until Apple ID
/// and Google sign-in are configured — the rows could only ever show
/// "disconnected" and a Connect button that links nothing.
const _showConnectedAccounts = false;

class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({required this.s, super.key});
  final PatientAppState s;
  @override
  ConsumerState<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

/// The text fields, and the save button's in-flight and "saved" flags (view
/// state). Gender, nationality, date of birth, the new contact's relationship
/// and the claimed handle are in [ProfileEditDraft]; the handle's
/// availability is [handleCheckProvider].
class _PersonalDetailsScreenState extends ConsumerState<PersonalDetailsScreen> {
  // Profile fields — all seeded ONCE from the real /account/self on first load
  // (no prototype sample identity). display name, phone, national ID, etc. are
  // now editable and persisted via PATCH /account/profile.
  final handle = TextEditingController();
  // Server stores a single display_name; the screen edits it as first + last
  // (design layout) and joins/splits on save/load.
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nidCtrl = TextEditingController(); // national ID (PHI/PII)

  // Emergency-contact fields feed the real AddEmergencyContactUseCase, so
  // they start empty (an "add new contact" form) rather than seeded sample PHI.
  final emName = TextEditingController();
  final emPhone = TextEditingController();

  bool saved = false;
  bool _saving = false;
  bool _fieldsSeeded = false; // text controllers seeded from the profile fetch

  /// Keys this screen's draft and handle check.
  final Object _form = Object();

  /// A profile always has a handle: clearing it is an error, not "none".
  HandleCheckKey get _handleKey => (form: _form, required: true);

  PatientAppState get s => widget.s;

  ProfileEditDraftNotifier get _draft => ref.read(profileEditDraftProvider(_form).notifier);
  HandleCheckController get _handleCheck => ref.read(handleCheckProvider(_handleKey).notifier);

  void _setHandle(String raw) {
    final v = _handleCheck.changed(raw, original: ref.read(profileEditDraftProvider(_form)).origHandle);
    if (handle.text != v) {
      handle.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    }
  }

  @override
  void dispose() {
    handle.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _nidCtrl.dispose();
    emName.dispose();
    emPhone.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// User-facing text for a failure.
  ///
  /// Only [OfflineFailure] is localised. Every other [AppFailure] still carries
  /// its own English message — a pre-existing gap across the whole hierarchy,
  /// not something the offline work introduced.
  String _failureText(AppFailure f) =>
      f is OfflineFailure ? AppScope.of(context).strings.common.offline_write : f.message;

  /// Persists the profile via PATCH /account/profile, then — if the handle was
  /// changed and verified available — claims it. Refreshes both the screen-local
  /// profile and the app-wide account summary so every screen reflects the edit.
  /// Save entry point. A changed handle retires the patient's public link, so
  /// it is confirmed first (`hc_*` sheet) rather than swapped silently.
  Future<void> _requestSave() async {
    final draft = ref.read(profileEditDraftProvider(_form));
    if (_saving || !draft.loaded) return;
    final next = handle.text.trim();
    if (next.isEmpty) {
      _handleCheck.markRequired();
      return;
    }
    if (!ref.read(handleCheckProvider(_handleKey)).acceptable) return;
    if (next == draft.origHandle) return _save();
    final confirmed = await _confirmHandleChange(draft.origHandle, next);
    if (!mounted) return;
    if (!confirmed) {
      // Cancelling restores the claimed handle so the field never lies about
      // what the account actually resolves to.
      handle.text = draft.origHandle;
      _handleCheck.settle(draft.origHandle);
      return;
    }
    await _save();
  }

  Future<bool> _confirmHandleChange(String from, String next) async =>
      await showAppSheet<bool>(
        context,
        textDirection: s.dir,
        builder: (_) => _HandleChangeSheet(s: s, from: from, to: next),
      ) ??
      false;

  Future<void> _save() async {
    // Never submit before the profile has loaded — empty controllers would
    // clear the user's data server-side.
    final draft = ref.read(profileEditDraftProvider(_form));
    if (!ref.read(handleCheckProvider(_handleKey)).acceptable || _saving || !draft.loaded) return;
    setState(() => _saving = true);

    // 1) Profile fields (display name, bio, gender, nationality, phone, DOB,
    //    national ID). Empty string clears a field; DOB is 18+ gated server-side.
    final profileResult = await ref.read(accountProfileUseCaseProvider).update(
          UpdateProfileInput(
            firstName: _firstCtrl.text.trim(),
            lastName: _lastCtrl.text.trim(),
            gender: draft.gender,
            nationality: draft.nationality?.value,
            phone: _phoneCtrl.text.trim(),
            dateOfBirth: draft.isoDob,
            nationalId: _nidCtrl.text.trim(),
            // Kept on the device for a device-only account, which cannot claim
            // one on the server; online, the claim below sets it.
            handle: handle.text.trim(),
          ),
        );
    if (!mounted) return;
    if (profileResult.isFailure) {
      setState(() => _saving = false);
      _snack(_failureText(profileResult.error));
      return;
    }

    // 2) Handle claim, only when the handle actually changed and is available.
    final newHandle = handle.text.trim();
    // A device-only account has just stored it on the device; nothing to claim.
    if (s.accountMode == AccountMode.deviceOnly) _draft.handleClaimed(newHandle);
    final available = ref.read(handleCheckProvider(_handleKey)).status == UsernameStatus.available;
    if (newHandle != ref.read(profileEditDraftProvider(_form)).origHandle && available) {
      final claim = await ref.read(claimHandleUseCaseProvider).execute(newHandle);
      if (!mounted) return;
      if (claim.isFailure) {
        _handleCheck.markTaken();
        setState(() => _saving = false);
        _snack(_failureText(claim.error));
        return;
      }
      _draft.handleClaimed(newHandle);
    }

    await refreshAccountSummary(ref);
    ref
      ..invalidate(profileDetailsProvider)
      // Re-derive the completion card from the freshly saved fields.
      ..invalidate(profileGapsProvider);
    if (!mounted) return;
    // Gendered copy and the body map follow the saved gender straight away. The
    // seeding above runs once per open, so without this a gender changed here
    // only reached the rest of the app the next time this screen was opened.
    s.setGender(draft.gender ?? Gender.other);
    _handleCheck.settle(newHandle);
    setState(() {
      _saving = false;
      saved = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => saved = false);
    });
  }

  /// Persists the emergency-contact form via AddEmergencyContactUseCase
  /// (on-device PHI only). FR-213: normalize Arabic-Indic phone digits first.
  Future<void> _addEmergencyContact() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final name = emName.text.trim();
    final contactPhone = toWesternDigits(emPhone.text).trim();
    if (name.isEmpty || contactPhone.isEmpty) return;
    final result = await ref.read(addEmergencyContactUseCaseProvider).execute(
          userId: userId,
          name: name,
          phone: contactPhone,
          relation: ref.read(profileEditDraftProvider(_form)).emRelation?.wire,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      emName.clear();
      emPhone.clear();
      _draft.setEmRelation(null);
      ref.invalidate(_emergencyContactsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error.message)));
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final current = ref.read(profileEditDraftProvider(_form)).dob;
    final picked = await showBalsmDatePicker(
      context,
      initial: current ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      title: s.strings.onboarding.dob_title,
      confirmLabel: s.strings.onboarding.dob_confirm,
      months: s.strings.settings.cal_months.split('|'),
      weekdays: s.strings.settings.cal_weekdays.split('|'),
      rtl: s.rtl,
      accent: s.accent.main,
    );
    if (picked != null && mounted) _draft.setDob(picked);
  }

  Future<void> _pickNationality() async {
    final picked = await showAppSheet<CountryCode>(
      context,
      textDirection: s.dir,
      builder: (_) => _NationalitySheet(current: ref.read(profileEditDraftProvider(_form)).nationality, s: s),
    );
    if (picked != null && mounted) _draft.setNationality(picked);
  }

  Future<void> _pickRelationship() async {
    final picked = await showAppSheet<Relationship>(
      context,
      textDirection: s.dir,
      builder: (_) => _RelationshipSheet(current: ref.read(profileEditDraftProvider(_form)).emRelation, s: s),
    );
    if (picked != null && mounted) _draft.setEmRelation(picked);
  }

  /// Seeds the text fields ONCE from the real /account/self on first load
  /// (no prototype sample identity). Name comes back as split first/last.
  void _seedFields(ProfileDetails profile) {
    _fieldsSeeded = true;
    handle.text = profile.handle ?? '';
    _firstCtrl.text = profile.firstName ?? '';
    _lastCtrl.text = profile.lastName ?? '';
    _phoneCtrl.text = profile.phone ?? '';
    _nidCtrl.text = profile.nationalId ?? '';
    // setGender notifies AppScope, which may not be marked dirty mid-build.
    final g = profile.gender ?? Gender.other;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) s.setGender(g);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Real on-device emergency contacts (PHI). Empty while loading / signed out.
    final contacts = ref.watch(_emergencyContactsProvider).value ?? const <EmergencyContact>[];
    final atMaxContacts = contacts.length >= AddEmergencyContactUseCase.maxContacts;

    final profile = ref.watch(profileDetailsProvider).value;
    if (!_fieldsSeeded && profile != null) _seedFields(profile);
    final loaded = ref.watch(profileEditDraftProvider(_form).select((d) => d.loaded));
    final handleOk = ref.watch(handleCheckProvider(_handleKey).select((h) => h.acceptable));
    final canSave = handleOk && !_saving && loaded;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          const PadTop(),
          AppBarRow(
            leading: RoundBtn(
              icon: backArrow(context),
              semanticLabel: s.strings.common.a11y_back,
              onTap: () => Navigator.pop(context),
            ),
            children: [
              Expanded(
                child: Text(
                  s.strings.profile.p_personal,
                  style: Typo.heading(ar: s.rtl).copyWith(fontSize: FontSizes.heading),
                ),
              ),
              if (saved) Pill(s.strings.profile.pd_saved, kind: PillKind.success, ar: s.rtl),
            ],
          ),
          Expanded(
            child: ContentColumn(
              maxWidth: 560,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 28),
                children: [
                  // Avatar (initials from the live name fields).
                  Center(
                    child: Column(
                      children: [
                        Avatar(
                          initials: _initials('${_firstCtrl.text} ${_lastCtrl.text}'.trim()),
                          color: AppColors.hueAqua,
                          size: 72,
                          fontSize: FontSizes.title,
                        ),
                      ],
                    ),
                  ),
                  // Account (handle + QR share)
                  _Section(icon: LucideIcons.atSign, title: s.strings.profile.pd_account, s: s),
                  _Card([_HandleField(controller: handle, checkKey: _handleKey, onChanged: _setHandle, s: s)]),
                  // Connected accounts — visual match of home.jsx. Hidden behind
                  // [_showConnectedAccounts] until Apple/Google sign-in is set up.
                  if (_showConnectedAccounts) ...[
                    _Section(icon: LucideIcons.link, title: s.strings.profile.conn_accounts, s: s),
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.sm,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _ConnectedRow(apple: true, label: s.strings.profile.conn_apple, last: false, s: s),
                          _ConnectedRow(apple: false, label: s.strings.profile.conn_google, last: true, s: s),
                        ],
                      ),
                    ),
                  ],
                  // Basic info — name (→ display_name), date of birth (PHI, 18+),
                  // gender. All persisted via PATCH /account/profile.
                  _Section(icon: LucideIcons.user, title: s.strings.profile.pd_basic_info, s: s),
                  _Card([
                    Row(
                      children: [
                        Expanded(
                          child: _TextFieldRow(label: s.strings.onboarding.pf_fname, controller: _firstCtrl, s: s),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TextFieldRow(label: s.strings.onboarding.pf_lname, controller: _lastCtrl, s: s),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Labeled(
                      label: s.strings.onboarding.pf_dob,
                      s: s,
                      child: _DobField(form: _form, onTap: _pickDob),
                    ),
                    const SizedBox(height: 14),
                    _Labeled(
                      label: s.strings.onboarding.pf_gender,
                      s: s,
                      child: _GenderSeg(form: _form, s: s),
                    ),
                  ]),
                  // Contact — phone, national ID (PHI/PII, encrypted), nationality.
                  _Section(icon: LucideIcons.phone, title: s.strings.profile.pd_contact_section, s: s),
                  _Card([
                    _Labeled(label: s.strings.profile.pd_phone, s: s, child: PhoneField(controller: _phoneCtrl)),
                    const SizedBox(height: 14),
                    _TextFieldRow(label: s.strings.profile.pd_nid, controller: _nidCtrl, mono: true, s: s),
                    const SizedBox(height: 14),
                    _Labeled(
                      label: s.strings.profile.pd_nationality,
                      s: s,
                      child: _NationalityField(form: _form, onTap: _pickNationality, s: s),
                    ),
                  ]),

                  // Emergency contact (real on-device PHI; up to 3 contacts).
                  _Section(icon: LucideIcons.phoneCall, title: s.strings.profile.pd_emergency, s: s),
                  _Card([
                    ...contacts.indexed.map(
                      (e) => Padding(
                        padding: EdgeInsets.only(
                          bottom: e.$1 < contacts.length - 1 || !atMaxContacts ? 12 : 0,
                        ),
                        child: _ContactRow(contact: e.$2, s: s),
                      ),
                    ),
                    if (!atMaxContacts) ...[
                      _TextFieldRow(label: s.strings.profile.pd_em_name, controller: emName, s: s),
                      const SizedBox(height: 14),
                      // Stacked, not side by side: the phone field carries a
                      // country-code picker and needs the full card width.
                      _Labeled(
                        label: s.strings.profile.pd_em_rel,
                        s: s,
                        child: _RelationField(form: _form, onTap: _pickRelationship, s: s),
                      ),
                      const SizedBox(height: 14),
                      _Labeled(label: s.strings.profile.pd_em_phone, s: s, child: PhoneField(controller: emPhone)),
                      const SizedBox(height: 14),
                      PButton(
                        s.strings.profile.pd_add_contact,
                        icon: LucideIcons.plus,
                        variant: BtnVariant.secondary,
                        block: true,
                        accent: s.accent,
                        ar: s.rtl,
                        onTap: _addEmergencyContact,
                      ),
                    ],
                  ]),
                  const SizedBox(height: 24),
                  // Saves the profile (and claims a changed+available handle).
                  // Disabled until loaded and while a handle is mid-check / bad.
                  Opacity(
                    opacity: canSave ? 1 : 0.4,
                    child: PButton(
                      saved ? s.strings.profile.pd_saved : s.strings.profile.pd_save,
                      icon: saved ? LucideIcons.check : LucideIcons.save,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: canSave ? _requestSave : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Two-letter initials from the display name (first letters of up to two
  /// words); '?' when the name is unknown.
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first.substring(0, 1);
    final b = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (a + b).toUpperCase();
  }
}

/// Localized label for a stored relation wire-code; falls back to the raw
/// stored string for legacy free-text values (returns null when unset).
String? _relationLabel(String? code, PatientAppState s) {
  if (code == null || code.isEmpty) return null;
  final rel = Relationship.tryFromCode(code);
  return rel == null ? code : rel.label(kCatalog, locale: s.lang.value);
}

/// Read-only styled row for an existing emergency contact (prototype look).
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.s});
  final EmergencyContact contact;
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final rel = _relationLabel(c.relation, s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.ink50, borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    if (c.isPrimary) ...[
                      const SizedBox(width: 7),
                      Pill(
                        s.strings.profile.pd_primary,
                        kind: PillKind.info,
                        dot: false,
                        ar: s.rtl,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  rel == null ? c.phone : '$rel · ${c.phone}',
                  textDirection: c.relation == null ? TextDirection.ltr : s.dir,
                  style: Typo.meta(ar: s.rtl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The handle field with its live availability: border tint, status icon and
/// message follow [handleCheckProvider].
class _HandleField extends ConsumerWidget {
  const _HandleField({required this.controller, required this.checkKey, required this.onChanged, required this.s});
  final TextEditingController controller;
  final HandleCheckKey checkKey;
  final ValueChanged<String> onChanged;
  final PatientAppState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(handleCheckProvider(checkKey).select((h) => h.status));
    final statusColor = switch (status) {
      UsernameStatus.available => AppColors.hueMint600,
      UsernameStatus.taken || UsernameStatus.required => AppColors.danger,
      UsernameStatus.invalid => AppColors.sun500,
      _ => s.accent.main,
    };
    final message = switch (status) {
      UsernameStatus.checking => s.strings.auth.un_checking,
      UsernameStatus.available => s.strings.auth.un_avail,
      UsernameStatus.taken => s.strings.auth.un_taken,
      UsernameStatus.invalid => s.strings.auth.un_invalid,
      UsernameStatus.required => s.strings.auth.un_required,
      _ => null,
    };
    final icon = switch (status) {
      UsernameStatus.available => LucideIcons.checkCircle2,
      UsernameStatus.taken => LucideIcons.xCircle,
      UsernameStatus.invalid || UsernameStatus.required => LucideIcons.alertCircle,
      _ => null,
    };
    return _Labeled(
      label: s.strings.auth.un_label,
      s: s,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textDirection: TextDirection.ltr,
            onChanged: onChanged,
            style: Typo.num(size: FontSizes.subhead),
            decoration: InputDecoration(
              isDense: true,
              // `UsernameField` paints the "@" as an always-on glyph inside
              // the input. `prefixText` only appears once the field is focused
              // or non-empty, so an empty handle lost the affordance entirely;
              // prefixIcon renders unconditionally.
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 2),
                child: Text(
                  '@',
                  style: Typo.num(size: FontSizes.subhead, weight: FontWeight.w700, color: AppColors.textTertiary),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(),
              // Status icon: spinner while checking, then check / x / alert.
              suffixIcon: status == UsernameStatus.checking
                  ? const Center(widthFactor: 1, child: Spinner(size: 16, stroke: 2, color: AppColors.textTertiary))
                  : (icon == null ? null : Icon(icon, size: 18, color: statusColor)),
              suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              filled: true, fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              // InputDecorator animates the border colour over ~200ms as the
              // handle validates (border tints mint / red / amber).
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(
                  color: status == UsernameStatus.idle ? AppColors.border : statusColor,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(
                  color: status == UsernameStatus.idle ? s.accent.main : statusColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
          // Validation message — slides in/out smoothly as status changes.
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.easeOut,
            alignment: AlignmentDirectional.topStart,
            child: switch (message) {
              final message? => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    message,
                    style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              _ => const SizedBox(width: double.infinity)
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.info, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 5),
              Text(
                s.strings.profile.pd_handle_hint,
                style: Typo.num(size: FontSizes.meta, color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectedRow extends StatelessWidget {
  const _ConnectedRow({required this.apple, required this.label, required this.last, required this.s});
  final bool apple;
  final String label;
  final bool last;
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.ink100))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: apple ? AppColors.nearBlack : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: apple ? null : Border.all(color: AppColors.ink100),
            ),
            child: apple
                ? const Icon(Icons.apple, size: 20, color: AppColors.white)
                : SvgPicture.string(_kGoogleGSvg, width: 18, height: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          PButton(
            s.strings.profile.conn_connect,
            variant: BtnVariant.soft,
            size: BtnSize.sm,
            accent: s.accent,
            ar: s.rtl,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.s});
  final IconData icon;
  final String title;
  final PatientAppState s;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0, 18, 0, 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: s.accent.main),
            const SizedBox(width: 8),
            Text(
              title,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child, required this.s});
  final String label;
  final Widget child;
  final PatientAppState s;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Typo.meta(ar: s.rtl).copyWith(
              fontSize: FontSizes.meta,
              fontWeight: FontWeight.w700,
              letterSpacing: s.rtl ? 0 : FontSizes.meta * 0.08,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
}

class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({required this.label, required this.controller, required this.s, this.mono = false});
  final String label;
  final TextEditingController controller;
  final PatientAppState s;
  final bool mono;

  @override
  Widget build(BuildContext context) => _Labeled(
        label: label,
        s: s,
        child: TextField(
          controller: controller,
          textDirection: mono ? TextDirection.ltr : s.dir,
          style: mono
              ? Typo.num(size: FontSizes.subhead)
              : Typo.body(ar: s.rtl).copyWith(fontSize: FontSizes.subhead, color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      );
}

/// A tappable 52px box that opens a picker and shows its choice ([child]),
/// with the picker's icon at the end.
class _PickerBox extends StatelessWidget {
  const _PickerBox({required this.onTap, required this.trailing, required this.child});
  final VoidCallback onTap;
  final IconData trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(child: child),
              Icon(trailing, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      );
}

/// Date-of-birth field — opens a date picker; shows dd / mm / yyyy.
class _DobField extends ConsumerWidget {
  const _DobField({required this.form, required this.onTap});
  final Object form;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dob = ref.watch(profileEditDraftProvider(form).select((d) => d.dob));
    return _PickerBox(
      onTap: onTap,
      trailing: LucideIcons.calendar,
      child: Text(
        switch (dob) {
          final d? => '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}',
          null => '—',
        },
        textDirection: TextDirection.ltr,
        style: Typo.num(size: FontSizes.subhead, color: dob == null ? AppColors.textHint : AppColors.textPrimary),
      ),
    );
  }
}

/// Nationality field — opens a bottom-sheet country selector; shows the
/// localized demonym (e.g. "Egyptian" / "مصري") of the picked country.
class _NationalityField extends ConsumerWidget {
  const _NationalityField({required this.form, required this.onTap, required this.s});
  final Object form;
  final VoidCallback onTap;
  final PatientAppState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nationality = ref.watch(profileEditDraftProvider(form).select((d) => d.nationality));
    return _PickerBox(
      onTap: onTap,
      trailing: LucideIcons.chevronDown,
      child: Row(
        children: [
          if (nationality != null) ...[
            Text(_flagEmoji(nationality.value), style: const TextStyle(fontSize: _flagEmojiSize)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              nationality?.demonym(kCatalog, locale: s.lang.value) ?? '—',
              style: Typo.body(ar: s.rtl).copyWith(
                fontSize: FontSizes.subhead,
                fontWeight: FontWeight.w600,
                color: nationality == null ? AppColors.textHint : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Relationship field — opens a bottom-sheet selector of [Relationship]
/// values, shown as localized labels.
class _RelationField extends ConsumerWidget {
  const _RelationField({required this.form, required this.onTap, required this.s});
  final Object form;
  final VoidCallback onTap;
  final PatientAppState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relation = ref.watch(profileEditDraftProvider(form).select((d) => d.emRelation));
    return _PickerBox(
      onTap: onTap,
      trailing: LucideIcons.chevronDown,
      child: Text(
        relation?.label(kCatalog, locale: s.lang.value) ?? '—',
        overflow: TextOverflow.ellipsis,
        style: Typo.body(ar: s.rtl).copyWith(
          fontSize: FontSizes.subhead,
          fontWeight: FontWeight.w600,
          color: relation == null ? AppColors.textHint : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _GenderSeg extends ConsumerWidget {
  const _GenderSeg({required this.form, required this.s});
  final Object form;
  final PatientAppState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gender = ref.watch(profileEditDraftProvider(form).select((d) => d.gender));
    final draft = ref.read(profileEditDraftProvider(form).notifier);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Seg(
            label: s.strings.onboarding.pf_female,
            active: gender == Gender.female,
            onTap: () => draft.setGender(Gender.female),
            s: s,
          ),
          const SizedBox(width: 6),
          _Seg(
            label: s.strings.onboarding.pf_male,
            active: gender == Gender.male,
            onTap: () => draft.setGender(Gender.male),
            s: s,
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.active, required this.onTap, required this.s});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final PatientAppState s;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.segment),
              boxShadow: active ? AppShadows.xs : null,
            ),
            child: Text(
              label,
              style: Typo.bodySm(ar: s.rtl).copyWith(
                fontWeight: FontWeight.w600,
                color: active ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      );
}

/// Regional-indicator flag emoji from a 2-letter ISO country code.
String _flagEmoji(String code) {
  if (code.length != 2) return '🏳️';
  return String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
}

/// Nationality picker — a searchable bottom sheet over every supported
/// nationality ([CountryCode.supportedNationalities], the full ISO set): flag +
/// localized demonym, filtered by demonym / country name / code. Returns the
/// chosen [CountryCode]. Mirrors the auth flow's dial-code sheet styling.
class _NationalitySheet extends StatefulWidget {
  const _NationalitySheet({required this.current, required this.s});
  final CountryCode? current;
  final PatientAppState s;
  @override
  State<_NationalitySheet> createState() => _NationalitySheetState();
}

class _NationalitySheetState extends State<_NationalitySheet> {
  final _search = TextEditingController();
  PatientAppState get s => widget.s;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = s.lang.value;
    final q = _search.text.trim().toLowerCase();
    final items = CountryCode.supportedNationalities.where((c) {
      if (q.isEmpty) return true;
      return c.demonym(kCatalog, locale: locale).toLowerCase().contains(q) ||
          c.name(kCatalog, locale: locale).toLowerCase().contains(q) ||
          c.value.toLowerCase().contains(q);
    }).toList();
    return Directionality(
      textDirection: s.dir,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const SheetGrab(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    s.strings.profile.pd_nationality,
                    style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textDirection: s.dir,
                  style: Typo.body(ar: s.rtl).copyWith(fontSize: FontSizes.bodyLg),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textHint),
                    hintText: s.strings.profile.pd_nationality,
                    filled: true,
                    fillColor: AppColors.ink50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, c),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        child: Row(
                          children: [
                            Text(_flagEmoji(c.value), style: const TextStyle(fontSize: _flagEmojiSizeLarge)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                c.demonym(kCatalog, locale: locale),
                                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (c == widget.current)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 8),
                                child: Icon(LucideIcons.checkCircle2, size: 18, color: s.accent.main),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Relationship picker — a bottom sheet of the [Relationship] values shown as
/// localized labels; returns the chosen value. No search (short fixed list).
class _RelationshipSheet extends StatelessWidget {
  const _RelationshipSheet({required this.current, required this.s});
  final Relationship? current;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) {
    final locale = s.lang.value;
    return Directionality(
      textDirection: s.dir,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const SheetGrab(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  s.strings.profile.pd_em_rel,
                  style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: Relationship.values
                    .map(
                      (r) => GestureDetector(
                        onTap: () => Navigator.pop(context, r),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.label(kCatalog, locale: locale),
                                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (r == current)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(start: 8),
                                  child: Icon(LucideIcons.checkCircle2, size: 18, color: s.accent.main),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Emergency-card QR share (qrshare.jsx `QRShareSheet` look, real data): mints
/// an AES-256-GCM-encrypted emergency token via `mintEmergencyQrTokenUseCase`
/// and renders a rounded-dot QR of `{BASE_URL}/emergency/{jti}#k={key}` with the
/// Balsm flower in its center. The decryption key lives ONLY in the URL fragment
/// (`#k=`) — it is embedded in the QR / clipboard locally and is NEVER sent to
/// the server (FR-013/FR-014). The token is permanent and minted offline-first
/// (the jti is generated on-device, the server sync is best-effort), so the
/// code appears without a connection; an active token offers Revoke / Rotate.
/// Slides up; in-sheet toast confirms copy/save/revoke.
/// Opens the patient's shareable QR.
///
/// `home.jsx` moved this out of Account details and onto the Profile tab, so
/// the entry point is [ProfileScreen] now — but the sheet itself, with its
/// mint/rotate/revoke controller, stays here next to the rest of the account
/// surface.
///
/// Sharing needs a server account, so a device-only account is offered the
/// go-online sheet first ([requireOnline]).
Future<void> openQrShare(BuildContext context, {required PatientAppState s, required String name}) async {
  if (!await requireOnline(context)) return;
  if (!context.mounted) return;
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (_) => _QrShareSheet(s: s, name: name),
  );
}

class _QrShareSheet extends ConsumerStatefulWidget {
  const _QrShareSheet({required this.s, required this.name});
  final PatientAppState s;
  final String name;
  @override
  ConsumerState<_QrShareSheet> createState() => _QrShareSheetState();
}

class _QrShareSheetState extends ConsumerState<_QrShareSheet> {
  // Ephemeral view state only (CODING_STANDARDS §7): the in-sheet toast and
  // the export-in-flight flag. Everything token-shaped lives in
  // [QrShareController]; restore/mint/revoke/rotate/countdown happen there.
  String? toast;
  Timer? _toastTimer;

  /// Captures the rendered QR card for share / save-to-gallery.
  final GlobalKey _qrCardKey = GlobalKey();
  bool _exporting = false;

  PatientAppState get s => widget.s;
  bool get ar => s.rtl;

  // Bridge getters over the controller state so the build helpers below read
  // naturally; build() watches the provider, so they are always current.
  QrShareState get _qs => ref.read(qrShareControllerProvider);
  MintResult? get _mint => _qs.mint;
  bool get _minting => _qs.minting;
  bool get _revoking => _qs.revoking;
  bool get _rotating => _qs.rotating;
  String? get _error => _qs.error;
  Duration get _remaining => _qs.remaining;
  bool get _isPermanent => _qs.isPermanent;
  bool get _isExpired => _qs.isExpired;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Called after awaits (saving the image), when the sheet may be gone.
  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => toast = null);
    });
  }

  /// Mints the real emergency token. The use-case reads the on-device snapshot
  /// via the Tier-0 seam, client-side AES-256-GCM encrypts it, POSTs ONLY the
  /// ciphertext, and returns the full QR URL with the key in the `#k=` fragment.
  Future<void> _mintToken() async {
    // Failures — incl. the age gate (FR-301b) — surface via state.error.
    await ref.read(qrShareControllerProvider.notifier).mint();
  }

  /// Revokes the active token; on success the QR clears and the sheet
  /// returns to the mint affordance.
  Future<void> _revoke() async {
    final ok = await ref.read(qrShareControllerProvider.notifier).revoke();
    if (ok && mounted) _showToast(s.strings.emergency.eqr_revoked_toast);
  }

  /// Copies the full QR URL (incl. the `#k=` fragment) to the clipboard. This is
  /// a local share only — the key still never reaches the server.
  void _copy() {
    final m = _mint;
    if (m == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: m.qrUrl)));
    _showToast(s.strings.emergency.eqr_link_copied);
  }

  /// Rasterises the QR card exactly as shown (flower mark, name, chip).
  /// User-initiated export: the QR encodes the key-bearing URL, so producing
  /// an image of it is the point — but it still never gets logged.
  Future<Uint8List?> _captureQrPng() async {
    final boundary = _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// Spec v2.0 rotate: revoke + fresh mint in one act, for a leaked or
  /// photographed code. Old copies stop resolving immediately.
  Future<void> _rotate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(s.strings.emergency.eqr_rotate_confirm(s.gender)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.strings.common.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.strings.emergency.eqr_rotate_yes, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref.read(qrShareControllerProvider.notifier).rotate();
    if (!mounted) return;
    _showToast(ok ? s.strings.emergency.eqr_rotated_toast : s.strings.emergency.eqr_rotate_failed(s.gender));
  }

  String _scanClientLabel(QrScanEntry e) => switch (e.client) {
        'web' => s.strings.emergency.eqr_scan_client_web,
        'app' => s.strings.emergency.eqr_scan_client_app,
        _ => s.strings.emergency.eqr_scan_client_unknown,
      };

  /// Owner's own scan history (spec v2.0): when the QR was resolved and by
  /// what coarse client class — never who.
  Future<void> _showScanHistory() async {
    final result = await ref.read(getQrScanHistoryUseCaseProvider)();
    if (!mounted) return;
    final scans = result.fold((v) => v, (_) => null);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.strings.emergency.eqr_scan_history,
                style: Typo.title(ar: ar).copyWith(fontSize: FontSizes.subhead, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (scans == null || scans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(s.strings.emergency.eqr_scans_empty, style: Typo.body(ar: ar))),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: scans.length,
                    itemBuilder: (_, i) {
                      final e = scans[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          e.client == 'app' ? LucideIcons.smartphone : LucideIcons.globe,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        title: Text(_scanClientLabel(e), style: Typo.body(ar: ar)),
                        subtitle: Text(
                          e.resolvedAt.toLocal().toString().substring(0, 16),
                          textDirection: TextDirection.ltr,
                          style: Typo.num(size: FontSizes.bodySm, color: AppColors.textTertiary),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _captureQrPng();
      if (bytes == null) return;
      if (kIsWeb) {
        // No photo library in a browser: hand the image over as a download.
        await FilePicker.saveFile(fileName: 'balsm-qr.png', bytes: bytes, mimeType: 'image/png');
      } else {
        await Gal.putImageBytes(bytes, name: 'balsm-qr');
      }
      _showToast(s.strings.emergency.eqr_saved_toast);
    } on GalException catch (e) {
      // A refused permission gets its own message and a way to Settings; any
      // other failure (storage, format) stays generic — nothing PHI-safe to add.
      if (e.type == GalExceptionType.permissionDenied && mounted) {
        showPermissionDenied(context, s.strings.emergency.eqr_save_denied);
      } else {
        _showToast(s.strings.emergency.eqr_save_failed);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareQr() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _captureQrPng();
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'balsm-qr.png')],
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String get _countdownLabel {
    if (_isExpired) return s.strings.emergency.eqr_expired;
    final d = _remaining;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    // Gate: signed-in only. The QR is a stable profile identity token
    // (booking, emergency, delegations bind to its jti) — an empty medical
    // profile still mints; the help text just nudges toward completing it.
    final userId = ref.watch(currentUserIdProvider);
    // Subscribe: the bridge getters below read this provider's current state.
    ref.watch(qrShareControllerProvider);
    final snapAsync = ref.watch(_emergencySnapshotProvider);
    final snapshot = snapAsync.value;
    final hasHealthData = snapshot != null && snapshot.hasAnyData;
    final canShare = userId != null;
    final loadingSnapshot = userId != null && snapAsync.isLoading;
    final hasToken = _mint != null;

    final String desc;
    if (hasToken) {
      desc = s.strings.emergency.eqr_help_active(s.gender);
    } else if (userId == null) {
      desc = s.strings.emergency.eqr_help_signin;
    } else if (!hasHealthData) {
      desc = s.strings.emergency.eqr_help_empty(s.gender);
    } else {
      desc = s.strings.emergency.eqr_help_create(s.gender);
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.cream50,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 12), child: SheetGrab()),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.strings.emergency.eqr_title,
                              style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          RoundBtn(
                            icon: LucideIcons.x,
                            semanticLabel: s.strings.common.a11y_close,
                            ghost: true,
                            iconSize: 17,
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 6, 20, 22 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child:
                            Text(desc, style: Typo.bodySm(ar: ar).copyWith(color: AppColors.textTertiary, height: 1.5)),
                      ),
                      if (hasToken)
                        ..._activeToken()
                      else if (loadingSnapshot)
                        ..._loadingState()
                      else if (!canShare)
                        ..._disabledState(signedOut: userId == null)
                      else
                        ..._mintAffordance(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // In-sheet toast (matches the prototype's slide-up confirmation).
          if (toast case final toast?)
            PositionedDirectional(
              start: 20,
              end: 20,
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
              child: RiseIn(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.ink900, borderRadius: BorderRadius.circular(AppRadii.lg)),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.checkCircle, size: 18, color: AppColors.hueMint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          toast,
                          style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The rounded-dot QR card with the flower center (prototype look). [dim]
  /// greys it once the token has expired. Wrapped in a [RepaintBoundary] so
  /// share / save-to-gallery export exactly what is on screen.
  Widget _qrCard(String data, {bool dim = false}) => RepaintBoundary(
        key: _qrCardKey,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.ink100),
            boxShadow: AppShadows.md,
          ),
          child: Column(
            children: [
              Opacity(
                opacity: dim ? 0.3 : 1,
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: data,
                        size: 240,
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.white,
                        // High EC so the centered flower stays scannable.
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.ink900),
                        dataModuleStyle:
                            const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.ink900),
                      ),
                      // Center flower mark with white halo (clears QR dots).
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: const [BoxShadow(color: AppColors.white, spreadRadius: 5)],
                        ),
                        child: const BalsmFlower(size: 42),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ..._identity(),
              const SizedBox(height: 8),
              // Expiry chip. A token minted before the permanent option was
              // withdrawn still reports `isPermanent`; it gets no chip rather than
              // a badge telling the patient their health QR never expires.
              if (_isPermanent)
                const SizedBox.shrink()
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isExpired ? AppColors.dangerBackground : s.accent.bg,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpired ? LucideIcons.timerOff : LucideIcons.timer,
                        size: 15,
                        color: _isExpired ? AppColors.danger : s.accent.d,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isExpired ? _countdownLabel : s.strings.emergency.eqr_expires_in(_countdownLabel),
                        style: Typo.num(
                          size: FontSizes.meta,
                          weight: FontWeight.w700,
                          color: _isExpired ? AppColors.danger : s.accent.d,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  /// Active-token view: live QR, copyable link, Save/Share + Revoke.
  List<Widget> _activeToken() {
    final m = _mint!;
    final expired = _isExpired;
    return [
      _qrCard(m.qrUrl, dim: expired),
      const SizedBox(height: 16),
      // Link row + copy. Shows the token path (key fragment elided from view).
      Container(
        padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.ink100),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.link, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.qrUrl.split('#').first,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.num(size: FontSizes.bodySm, color: AppColors.textSecondary),
              ),
            ),
            PButton(
              s.strings.emergency.eqr_copy,
              icon: LucideIcons.copy,
              variant: BtnVariant.ghost,
              accent: s.accent,
              ar: ar,
              onTap: expired ? null : _copy,
            ),
          ],
        ),
      ),
      // `qrshare.jsx` adds a permanence note here ("this is your permanent code
      // — it doesn't expire"). Deliberately not ported: the token has no expiry
      // but can still be revoked or rotated, so the sheet gives no reassurance
      // rather than a promise the app cannot keep. Guarded by
      // `test/qr_no_permanence_test.dart`.
      const SizedBox(height: 16),
      if (expired)
        // Token lapsed → offer a fresh mint (returns to the affordance).
        PButton(
          s.strings.emergency.eqr_generate_new,
          icon: LucideIcons.refreshCw,
          large: true,
          block: true,
          accent: s.accent,
          ar: ar,
          onTap: () {
            ref.read(qrShareControllerProvider.notifier).clearExpired();
          },
        )
      else ...[
        Row(
          children: [
            Expanded(
              child: PButton(
                s.strings.emergency.eqr_save,
                icon: LucideIcons.download,
                variant: BtnVariant.secondary,
                large: true,
                block: true,
                ar: ar,
                onTap: _exporting ? null : _saveToGallery,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PButton(
                s.strings.emergency.eqr_share,
                icon: LucideIcons.share2,
                large: true,
                block: true,
                accent: s.accent,
                ar: ar,
                onTap: _exporting ? null : _shareQr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_revoking)
          _busyButton()
        else
          PButton(
            s.strings.emergency.eqr_revoke,
            icon: LucideIcons.ban,
            variant: BtnVariant.ghost,
            block: true,
            ar: ar,
            color: AppColors.danger,
            onTap: _revoke,
          ),
        if (_isPermanent) ...[
          const SizedBox(height: 4),
          if (_rotating)
            _busyButton()
          else
            PButton(
              s.strings.emergency.eqr_rotate,
              icon: LucideIcons.refreshCcw,
              variant: BtnVariant.ghost,
              block: true,
              ar: ar,
              onTap: _rotate,
            ),
          const SizedBox(height: 4),
          PButton(
            s.strings.emergency.eqr_scan_history,
            icon: LucideIcons.history,
            variant: BtnVariant.ghost,
            block: true,
            ar: ar,
            onTap: _showScanHistory,
          ),
        ],
      ],
    ];
  }

  /// Whose code this is: the name, then the handle as `@handle` — the pair
  /// `qrshare.jsx` puts under the code, not the full URL (the copyable link
  /// already has its own row).
  ///
  /// Rendered under the QR AND above the pre-mint picker, because the card
  /// only exists once a token has been minted — before that the sheet
  /// identified nobody, which is the one thing a person opening "my QR code"
  /// is looking for.
  List<Widget> _identity() {
    final account = ref.watch(accountSummaryProvider);
    final handle = account.value?.handle;
    // `GET /account/self` failing (an expired session 401s through the
    // refresh) used to render as simply no handle — indistinguishable from
    // never having claimed one. Say which it is.
    if (account.hasError && (handle == null || handle.isEmpty)) {
      return [
        Text(
          s.strings.profile.acct_load_failed,
          textAlign: TextAlign.center,
          style: Typo.bodySm(ar: ar).copyWith(color: AppColors.textTertiary),
        ),
      ];
    }
    return [
      if (widget.name.isNotEmpty)
        Text(
          widget.name,
          textAlign: TextAlign.center,
          style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700),
        ),
      // The handle is Latin either way, so it stays LTR in Arabic.
      if (handle != null && handle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '@$handle',
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: Typo.num(size: FontSizes.bodySm, color: s.accent.main),
          ),
        ),
    ];
  }

  /// Pre-mint affordance: Generate, plus any mint error.
  List<Widget> _mintAffordance() => [
        ..._identity(),
        if (_error case final error?) ...[
          const SizedBox(height: 14),
          _ErrorBox(error),
        ],
        const SizedBox(height: 18),
        if (_minting)
          _busyButton(primary: true)
        else
          PButton(
            s.strings.emergency.eqr_generate,
            icon: LucideIcons.qrCode,
            large: true,
            block: true,
            accent: s.accent,
            ar: ar,
            onTap: _mintToken,
          ),
      ];

  /// Disabled/empty state — signed out or no health data (never crashes).
  List<Widget> _disabledState({required bool signedOut}) => [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.ink100),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            children: [
              Icon(signedOut ? LucideIcons.lock : LucideIcons.heartPulse, size: 40, color: AppColors.ink300),
              const SizedBox(height: 14),
              Text(
                signedOut ? s.strings.emergency.eqr_signin_required : s.strings.emergency.eqr_no_data,
                textAlign: TextAlign.center,
                style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Disabled Generate button (0.4 opacity, non-tappable) — prototype style.
        Opacity(
          opacity: 0.4,
          child: PButton(
            s.strings.emergency.eqr_generate,
            icon: LucideIcons.qrCode,
            large: true,
            block: true,
            accent: s.accent,
            ar: ar,
          ),
        ),
      ];

  List<Widget> _loadingState() => [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 60),
          alignment: Alignment.center,
          child: Spinner(size: 26, stroke: 2.5, color: s.accent.main),
        ),
      ];

  /// Button-shaped busy indicator (PButton has no loading prop).
  Widget _busyButton({bool primary = false}) => Container(
        height: primary ? 56 : 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? s.accent.main : AppColors.white,
          borderRadius: BorderRadius.circular(primary ? AppRadii.lg : AppRadii.md),
          border: primary ? null : Border.all(color: AppColors.borderStrong),
          boxShadow: primary ? s.accent.boxShadow : null,
        ),
        child: Spinner(size: 22, stroke: 2.5, color: primary ? AppColors.white : s.accent.main),
      );
}

/// Username-change confirmation (home.jsx's `hc_*` sheet): the old handle
/// struck through above the new one, so the patient sees exactly which public
/// link is being retired before it happens.
class _HandleChangeSheet extends StatelessWidget {
  const _HandleChangeSheet({required this.s, required this.from, required this.to});
  final PatientAppState s;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    final p = s.strings.profile;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      padding: const EdgeInsets.only(bottom: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(p.hc_title, style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700)),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 2, 0, 18),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.warningBackground, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.alertTriangle, size: 21, color: AppColors.sun500),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p.hc_body, style: Typo.bodySm(ar: ar).copyWith(height: 1.55))),
                    ],
                  ),
                ),
                _HandleRow(ar, p.hc_from, from, bg: AppColors.ink50, color: AppColors.textTertiary, strike: true),
                const SizedBox(height: 10),
                _HandleRow(ar, p.hc_to, to, bg: s.accent.bg, color: s.accent.d, bold: true),
                const SizedBox(height: 22),
                PButton(
                  p.hc_confirm,
                  large: true,
                  block: true,
                  accent: s.accent,
                  ar: ar,
                  onTap: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 10),
                PButton(
                  p.hc_cancel,
                  variant: BtnVariant.ghost,
                  block: true,
                  accent: s.accent,
                  ar: ar,
                  onTap: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _kGoogleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
</svg>
''';

class _Card extends StatelessWidget {
  const _Card(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// Mint/revoke error surfaced in the prototype's error style (danger wash).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.msg);
  final String msg;

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.dangerBackground, borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandleRow extends StatelessWidget {
  const _HandleRow(
    this.ar,
    this.label,
    this.value, {
    required this.bg,
    required this.color,
    this.strike = false,
    this.bold = false,
  });
  final bool ar;
  final String label;
  final String value;
  final Color bg;
  final Color color;
  final bool strike;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Row(
          children: [
            Text(label, style: Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Flexible(
              child: Text(
                '@$value',
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.num(size: FontSizes.bodySm, weight: bold ? FontWeight.w700 : FontWeight.w400, color: color)
                    .copyWith(decoration: strike ? TextDecoration.lineThrough : null, decorationColor: color),
              ),
            ),
          ],
        ),
      );
}
