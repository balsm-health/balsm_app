import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:core/core.dart'
    show currentUserIdProvider, accountSummaryProvider, accountApiProvider, Gender, CountryCode, CountryCodeL10n;
import 'package:account/account.dart'
    show claimHandleUseCaseProvider, accountProfileUseCaseProvider, ProfileDetails, UpdateProfileInput;
import 'package:emergency_card/emergency_card.dart'
    show
        EmergencyCardSnapshot,
        emergencySnapshotReaderProvider,
        mintEmergencyQrTokenUseCaseProvider,
        revokeEmergencyQrTokenUseCaseProvider,
        MintResult;
import 'package:profile/profile.dart'
    show
        EmergencyContact,
        profileDataSourceProvider,
        addEmergencyContactUseCaseProvider,
        AddEmergencyContactUseCase,
        normalizeArabicNumerals;
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;
import '../widgets/balsm_flower.dart';

/// Opens the account/identity editor (home.jsx AccountDetailsScreen).
void openPersonalDetails(BuildContext context) {
  final s = AppScope.of(context);
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    builder: (_) => Directionality(textDirection: s.dir, child: AdaptiveFrame(child: PersonalDetailsScreen(s: s))),
  ));
}

/// Reads the current user's emergency contacts from the on-device HealthProfile
/// (SQLCipher PHI). Re-runs on sign-in/out; empty when signed out. Adding a
/// contact via AddEmergencyContactUseCase invalidates this provider.
final _emergencyContactsProvider = FutureProvider.autoDispose<List<EmergencyContact>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final profile = await ref.watch(profileDataSourceProvider).getProfile(userId);
  return profile?.emergencyContacts ?? const [];
});

/// Reads the on-device [EmergencyCardSnapshot] via the Tier-0
/// `emergencySnapshotReaderProvider` seam (the same PHI the mint use-case
/// encrypts). Used only to gate the QR-share sheet's mint affordance: `null`
/// when signed out or when there is no profile yet. Never leaves the device.
final _emergencySnapshotProvider = FutureProvider.autoDispose<EmergencyCardSnapshot?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(emergencySnapshotReaderProvider).readSnapshot();
});

/// The signed-in user's full editable profile (PHI-carrying: DOB, national ID).
/// Screen-local — the PHI never enters the app-wide AccountSummary. Re-fetched
/// after a save so the head + fields reflect the server.
final _profileProvider = FutureProvider.autoDispose<ProfileDetails?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(accountProfileUseCaseProvider).load();
});

/// TTL choices offered before minting the emergency QR token (FR-017).
/// `key` is an app i69n label key.
const _emergencyTtlOptions = <({String key, int seconds})>[
  (key: 'emergency.eqr_ttl_1h', seconds: 3600),
  (key: 'emergency.eqr_ttl_6h', seconds: 21600),
  (key: 'emergency.eqr_ttl_24h', seconds: 86400),
  (key: 'emergency.eqr_ttl_7d', seconds: 604800),
];

class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key, required this.s});
  final PatientAppState s;
  @override
  ConsumerState<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

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
  CountryCode? _nationality; // picked from a bottom sheet (stored as ISO code)
  Gender? _gender; // null until loaded / chosen
  DateTime? _dob; // PHI

  // Emergency-contact fields feed the real AddEmergencyContactUseCase, so
  // they start empty (an "add new contact" form) rather than seeded sample PHI.
  final emName = TextEditingController();
  final emRel = TextEditingController();
  final emPhone = TextEditingController();

  bool saved = false;
  bool _saving = false;
  bool _loaded = false; // controllers seeded from the profile fetch

  // Handle availability — validated against the real /handle/check endpoint.
  // `_origHandle` is the currently-claimed handle; an unchanged handle is 'idle'.
  String _origHandle = '';
  // Backend handle format: 3–30 chars, a–z 0–9 _ or . (mirrors kHandleFormat).
  static final _handleFormat = RegExp(r'^[a-z0-9_.]{3,30}$');
  String unStatus = 'idle'; // idle | checking | available | taken | invalid
  Timer? _debounce;

  PatientAppState get s => widget.s;

  /// Block save only while the handle is mid-check or resolved bad — other
  /// profile fields are always saveable. A changed+available handle also claims.
  bool get _canSave => unStatus == 'idle' || unStatus == 'available';

  String? _fmtDob() => _dob == null
      ? null
      : '${_dob!.year.toString().padLeft(4, '0')}-'
          '${_dob!.month.toString().padLeft(2, '0')}-'
          '${_dob!.day.toString().padLeft(2, '0')}';

  void _setHandle(String raw) {
    final v = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (handle.text != v) {
      handle.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    }
    _debounce?.cancel();
    if (v.isEmpty || v == _origHandle) {
      setState(() => unStatus = 'idle');
      return;
    }
    if (!_handleFormat.hasMatch(v)) {
      setState(() => unStatus = 'invalid');
      return;
    }
    setState(() => unStatus = 'checking');
    _debounce = Timer(const Duration(milliseconds: 500), () => _check(v));
  }

  /// Live availability check against the real account API.
  Future<void> _check(String v) async {
    try {
      final res = await ref.read(accountApiProvider).checkHandleAvailability(v);
      if (!mounted || handle.text != v) return; // stale response — ignore
      setState(() => unStatus = res.available ? 'available' : 'taken');
    } catch (_) {
      // Network / server error — treat as "couldn't verify" (idle), never
      // block on a false-available. A genuinely-taken handle still fails at
      // claim time (409 → ConflictFailure).
      if (!mounted || handle.text != v) return;
      setState(() => unStatus = 'idle');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    handle.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _nidCtrl.dispose();
    emName.dispose();
    emRel.dispose();
    emPhone.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Persists the profile via PATCH /account/profile, then — if the handle was
  /// changed and verified available — claims it. Refreshes both the screen-local
  /// profile and the app-wide account summary so every screen reflects the edit.
  Future<void> _save() async {
    // Never submit before the profile has loaded — empty controllers would
    // clear the user's data server-side.
    if (!_canSave || _saving || !_loaded) return;
    setState(() => _saving = true);

    // 1) Profile fields (display name, bio, gender, nationality, phone, DOB,
    //    national ID). Empty string clears a field; DOB is 18+ gated server-side.
    final profileResult = await ref.read(accountProfileUseCaseProvider).update(UpdateProfileInput(
          firstName: _firstCtrl.text.trim(),
          lastName: _lastCtrl.text.trim(),
          gender: _gender,
          nationality: _nationality?.value,
          phone: _phoneCtrl.text.trim(),
          dateOfBirth: _fmtDob(),
          nationalId: _nidCtrl.text.trim(),
        ));
    if (!mounted) return;
    if (profileResult.isFailure) {
      setState(() => _saving = false);
      _snack(profileResult.error.message);
      return;
    }

    // 2) Handle claim, only when the handle actually changed and is available.
    final newHandle = handle.text.trim();
    if (newHandle != _origHandle && unStatus == 'available') {
      final claim = await ref.read(claimHandleUseCaseProvider).execute(newHandle);
      if (!mounted) return;
      final claimFailed = claim.isFailure;
      if (claimFailed) {
        setState(() {
          _saving = false;
          unStatus = 'taken';
        });
        _snack(claim.error.message);
        return;
      }
      _origHandle = newHandle;
    }

    ref.invalidate(accountSummaryProvider);
    ref.invalidate(_profileProvider);
    setState(() {
      _saving = false;
      unStatus = 'idle';
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
    final contactPhone = normalizeArabicNumerals(emPhone.text).trim();
    if (name.isEmpty || contactPhone.isEmpty) return;
    final relation = emRel.text.trim();
    final result = await ref.read(addEmergencyContactUseCaseProvider).execute(
          userId: userId,
          name: name,
          phone: contactPhone,
          relation: relation.isEmpty ? null : relation,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      emName.clear();
      emRel.clear();
      emPhone.clear();
      ref.invalidate(_emergencyContactsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error.message)));
    }
  }

  /// Read-only styled row for an existing emergency contact (prototype look).
  Widget _contactRow(EmergencyContact c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                  child: Text(c.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1))),
              if (c.isPrimary) ...[
                const SizedBox(width: 7),
                Pill(s.strings.profile.pd_primary,
                    kind: PillKind.info,
                    dot: false,
                    ar: s.rtl,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
              ],
            ]),
            const SizedBox(height: 3),
            Text(
              c.relation == null || c.relation!.isEmpty ? c.phone : '${c.relation} · ${c.phone}',
              textDirection: TextDirection.ltr,
              style: Typo.meta(ar: s.rtl),
            ),
          ])),
        ]),
      );

  Color get _handleStatusColor => switch (unStatus) {
        'available' => T.petalMint600,
        'taken' => T.danger,
        'invalid' => T.sun500,
        _ => s.accent.main,
      };

  String? get _handleMsg => switch (unStatus) {
        'checking' => s.strings.auth.un_checking,
        'available' => s.strings.auth.un_avail,
        'taken' => s.strings.auth.un_taken,
        'invalid' => s.strings.auth.un_invalid,
        _ => null,
      };

  Widget? _handleSuffix() {
    if (unStatus == 'checking') {
      return const Center(widthFactor: 1, child: Spinner(size: 16, stroke: 2, color: T.fg3));
    }
    final ico = switch (unStatus) {
      'available' => LucideIcons.checkCircle2,
      'taken' => LucideIcons.xCircle,
      'invalid' => LucideIcons.alertCircle,
      _ => null,
    };
    if (ico == null) return null;
    return Icon(ico, size: 18, color: _handleStatusColor);
  }

  @override
  Widget build(BuildContext context) {
    // Real on-device emergency contacts (PHI). Empty while loading / signed out.
    final contacts = ref.watch(_emergencyContactsProvider).valueOrNull ?? const <EmergencyContact>[];
    final atMaxContacts = contacts.length >= AddEmergencyContactUseCase.maxContacts;

    // Seed every editable field ONCE from the real /account/self on first load
    // (no prototype sample identity). Name comes back as split first/last.
    final profile = ref.watch(_profileProvider).valueOrNull;
    if (!_loaded && profile != null) {
      _loaded = true;
      _origHandle = profile.handle ?? '';
      handle.text = _origHandle;
      _firstCtrl.text = profile.firstName ?? '';
      _lastCtrl.text = profile.lastName ?? '';
      _phoneCtrl.text = profile.phone ?? '';
      _nidCtrl.text = profile.nationalId ?? '';
      // Stored as an ISO country code; legacy free-text values won't parse and
      // simply show the placeholder until re-selected.
      _nationality = (profile.nationality?.isNotEmpty ?? false) ? CountryCode.tryFromCode(profile.nationality!) : null;
      _gender = profile.gender;
      s.setGender(profile.gender ?? Gender.other);
      _dob = (profile.dateOfBirth?.isNotEmpty ?? false) ? DateTime.tryParse(profile.dateOfBirth!) : null;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        const PadTop(),
        AppBarRow(
          leading: RoundBtn(icon: backArrow(context), onTap: () => Navigator.pop(context)),
          children: [
            Expanded(
                child: Text(s.strings.profile.p_personal, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
            if (saved) ...[
              Pill(s.strings.profile.pd_saved, kind: PillKind.success, ar: s.rtl),
              const SizedBox(width: 8)
            ],
            RoundBtn(icon: LucideIcons.qrCode, iconSize: 19, onTap: () => _showQr(context)),
          ],
        ),
        Expanded(
            child: ContentColumn(
                maxWidth: 560,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    // Avatar (initials from the live name fields).
                    Center(
                        child: Column(children: [
                      Avatar(
                          initials: _initials('${_firstCtrl.text} ${_lastCtrl.text}'.trim()),
                          color: T.petalAqua,
                          size: 72),
                      const SizedBox(height: 10),
                      PButton(s.strings.profile.pd_change_photo,
                          icon: LucideIcons.camera, variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl),
                    ])),
                    // Account (handle + QR share)
                    _section(LucideIcons.atSign, s.strings.profile.pd_account),
                    _card([
                      _labeled(
                          s.strings.auth.un_label,
                          TextField(
                            controller: handle,
                            textDirection: TextDirection.ltr,
                            onChanged: _setHandle,
                            style: Typo.num(size: FS.lg),
                            decoration: InputDecoration(
                              isDense: true, prefixText: '@',
                              prefixStyle: Typo.num(size: FS.lg, weight: FontWeight.w700, color: T.fg3),
                              // Status icon: spinner while checking, then check / x / alert.
                              suffixIcon: _handleSuffix(),
                              suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              filled: true, fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              // InputDecorator animates the border colour over ~200ms as the
                              // handle validates (border tints mint / red / amber).
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(T.rMd),
                                  borderSide: BorderSide(
                                      color: unStatus == 'idle' ? T.border : _handleStatusColor, width: 1.5)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(T.rMd),
                                  borderSide: BorderSide(
                                      color: unStatus == 'idle' ? s.accent.main : _handleStatusColor, width: 1.5)),
                            ),
                          )),
                      // Validation message — slides in/out smoothly as status changes.
                      AnimatedSize(
                        duration: Motion.base,
                        curve: Motion.easeOut,
                        alignment: Alignment.topLeft,
                        child: _handleMsg == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(_handleMsg!,
                                    style: Typo.meta(ar: s.rtl)
                                        .copyWith(fontWeight: FontWeight.w600, color: _handleStatusColor)),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(LucideIcons.link, size: 12, color: T.fg4),
                        const SizedBox(width: 5),
                        Text('balsm.health/@${handle.text}',
                            textDirection: TextDirection.ltr, style: Typo.num(size: FS.xs, color: T.fg3)),
                      ]),
                      const SizedBox(height: 14),
                      Pressable(
                        onTap: () => _showQr(context),
                        scale: 0.98,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
                          child: Row(children: [
                            Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration:
                                    BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rSm)),
                                child: Icon(LucideIcons.qrCode, size: 20, color: s.accent.d)),
                            const SizedBox(width: 13),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.strings.profile.pd_share_qr,
                                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
                              Text(s.strings.profile.pd_share_qr_h,
                                  style: Typo.meta(ar: s.rtl).copyWith(color: s.accent.d)),
                            ])),
                            Chevron(rtl: s.rtl, color: s.accent.d),
                          ]),
                        ),
                      ),
                    ]),
                    // Basic info — name (→ display_name), date of birth (PHI, 18+),
                    // gender. All persisted via PATCH /account/profile.
                    _section(LucideIcons.user, s.strings.profile.pd_basic_info),
                    _card([
                      Row(children: [
                        Expanded(child: _field(s.strings.onboarding.pf_fname, _firstCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(s.strings.onboarding.pf_lname, _lastCtrl)),
                      ]),
                      const SizedBox(height: 14),
                      _labeled(s.strings.onboarding.pf_dob, _dobField()),
                      const SizedBox(height: 14),
                      _labeled(s.strings.onboarding.pf_gender, _genderSeg()),
                    ]),
                    // Contact — phone, national ID (PHI/PII, encrypted), nationality.
                    _section(LucideIcons.phone, s.strings.profile.pd_contact_section),
                    _card([
                      _field(s.strings.profile.pd_phone, _phoneCtrl, mono: true),
                      const SizedBox(height: 14),
                      _field(s.strings.profile.pd_nid, _nidCtrl, mono: true),
                      const SizedBox(height: 14),
                      _labeled(s.strings.profile.pd_nationality, _nationalityField()),
                    ]),

                    // Emergency contact (real on-device PHI; up to 3 contacts).
                    _section(LucideIcons.phoneCall, s.strings.profile.pd_emergency),
                    _card([
                      for (var i = 0; i < contacts.length; i++) ...[
                        _contactRow(contacts[i]),
                        if (i < contacts.length - 1 || !atMaxContacts) const SizedBox(height: 12),
                      ],
                      if (!atMaxContacts) ...[
                        _field(s.strings.profile.pd_em_name, emName),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: _field(s.strings.profile.pd_em_rel, emRel)),
                          const SizedBox(width: 12),
                          Expanded(child: _field(s.strings.profile.pd_em_phone, emPhone, mono: true)),
                        ]),
                        const SizedBox(height: 14),
                        PButton(s.strings.profile.pd_add_contact,
                            icon: LucideIcons.plus,
                            variant: BtnVariant.secondary,
                            block: true,
                            accent: s.accent,
                            ar: s.rtl,
                            onTap: _addEmergencyContact),
                      ],
                    ]),
                    const SizedBox(height: 24),
                    // Saves the profile (and claims a changed+available handle).
                    // Disabled until loaded and while a handle is mid-check / bad.
                    Opacity(
                      opacity: _canSave && !_saving && _loaded ? 1 : 0.4,
                      child: PButton(saved ? s.strings.profile.pd_saved : s.strings.profile.pd_save,
                          icon: saved ? LucideIcons.check : LucideIcons.save,
                          variant: BtnVariant.primary,
                          large: true,
                          block: true,
                          accent: s.accent,
                          ar: s.rtl,
                          onTap: _canSave && !_saving && _loaded ? _save : null),
                    ),
                  ],
                ))),
      ]),
    );
  }

  void _showQr(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x6B2B2B25),
      builder: (ctx) => Directionality(
        textDirection: s.dir,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _QrShareSheet(s: s, name: '${_firstCtrl.text} ${_lastCtrl.text}'.trim()),
          ),
        ),
      ),
    );
  }

  Widget _section(IconData icon, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
        child: Row(children: [
          Icon(icon, size: 16, color: s.accent.main),
          const SizedBox(width: 8),
          Text(title, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        ]),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: T.border),
            boxShadow: T.shadowSm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _labeled(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: Typo.meta(ar: s.rtl)
                .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, letterSpacing: s.rtl ? 0 : 0.8, color: T.fg3)),
        const SizedBox(height: 8),
        child,
      ]);

  Widget _field(String label, TextEditingController c, {bool mono = false}) => _labeled(
      label,
      TextField(
        controller: c,
        textDirection: mono ? TextDirection.ltr : s.dir,
        style: mono ? Typo.num(size: FS.lg) : Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, color: T.fg1),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      ));

  /// Date-of-birth field — opens a date picker; shows dd / mm / yyyy.
  Widget _dobField() => GestureDetector(
        onTap: _pickDob,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border, width: 1.5),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                _dob == null
                    ? '—'
                    : '${_dob!.day.toString().padLeft(2, '0')} / '
                        '${_dob!.month.toString().padLeft(2, '0')} / ${_dob!.year}',
                textDirection: TextDirection.ltr,
                style: Typo.num(size: FS.lg, color: _dob == null ? T.fg4 : T.fg1),
              ),
            ),
            const Icon(LucideIcons.calendar, size: 18, color: T.fg4),
          ]),
        ),
      );

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  /// Nationality field — opens a bottom-sheet country selector; shows the
  /// localized demonym (e.g. "Egyptian" / "مصري") of the picked country.
  Widget _nationalityField() => GestureDetector(
        onTap: _pickNationality,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border, width: 1.5),
          ),
          child: Row(children: [
            if (_nationality != null) ...[
              Text(_flagEmoji(_nationality!.value), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                _nationality == null ? '—' : _nationality!.demonym(kCatalog, locale: s.lang.value),
                style: Typo.body(ar: s.rtl).copyWith(
                    fontSize: FS.lg, fontWeight: FontWeight.w600, color: _nationality == null ? T.fg4 : T.fg1),
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 18, color: T.fg4),
          ]),
        ),
      );

  Future<void> _pickNationality() async {
    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5C2B2B25),
      builder: (_) => _NationalitySheet(current: _nationality, s: s),
    );
    if (picked != null && mounted) setState(() => _nationality = picked);
  }

  Widget _genderSeg() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: T.ink50, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.border)),
        child: Row(children: [
          _seg(s.strings.onboarding.pf_female, _gender == Gender.female, () => setState(() => _gender = Gender.female)),
          const SizedBox(width: 6),
          _seg(s.strings.onboarding.pf_male, _gender == Gender.male, () => setState(() => _gender = Gender.male)),
        ]),
      );

  Widget _seg(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: active ? T.shadowXs : null),
            child: Text(label,
                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: active ? T.fg1 : T.fg3)),
          ),
        ),
      );

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

/// Regional-indicator flag emoji from a 2-letter ISO country code.
String _flagEmoji(String code) {
  if (code.length != 2) return '🏳️';
  return String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
}

/// Nationality picker — a bottom sheet listing the curated countries with flag
/// + localized demonym; returns the chosen [CountryCode]. Mirrors the auth
/// flow's dial-code sheet styling.
class _NationalitySheet extends StatelessWidget {
  const _NationalitySheet({required this.current, required this.s});
  final CountryCode? current;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: s.dir,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration:
            const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(s.strings.profile.pd_nationality,
                  style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: CountryCode.known
                  .map((c) => GestureDetector(
                        onTap: () => Navigator.pop(context, c),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Row(children: [
                            Text(_flagEmoji(c.value), style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(c.demonym(kCatalog, locale: s.lang.value),
                                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600))),
                            if (c == current)
                              Padding(
                                  padding: const EdgeInsetsDirectional.only(start: 8),
                                  child: Icon(LucideIcons.checkCircle2, size: 18, color: s.accent.main)),
                          ]),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Emergency-card QR share (qrshare.jsx `QRShareSheet` look, real data): mints
/// an AES-256-GCM-encrypted emergency token via [mintEmergencyQrTokenUseCase]
/// and renders a rounded-dot QR of `{BASE_URL}/emergency/{jti}#k={key}` with the
/// Balsm flower in its center. The decryption key lives ONLY in the URL fragment
/// (`#k=`) — it is embedded in the QR / clipboard locally and is NEVER sent to
/// the server (FR-013/FR-014). Before minting, the user picks a TTL (FR-017);
/// an active token shows its expiry + a Revoke action. Slides up; in-sheet toast
/// confirms copy/save/revoke.
class _QrShareSheet extends ConsumerStatefulWidget {
  const _QrShareSheet({required this.s, required this.name});
  final PatientAppState s;
  final String name;
  @override
  ConsumerState<_QrShareSheet> createState() => _QrShareSheetState();
}

class _QrShareSheetState extends ConsumerState<_QrShareSheet> {
  String? toast;
  Timer? _toastTimer;

  // Minted-token state. `_mint` holds the real token + its `#k=` fragment URL;
  // null until a token is minted (or after it is revoked / re-generated).
  MintResult? _mint;
  int _ttlSeconds = 86400; // default 24h (FR-017)
  bool _minting = false;
  bool _revoking = false;
  String? _error;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  PatientAppState get s => widget.s;
  bool get ar => s.rtl;

  bool get _isExpired => _mint == null || _remaining.isNegative || _remaining == Duration.zero;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _showToast(String msg) {
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
    setState(() {
      _minting = true;
      _error = null;
    });
    final result = await ref.read(mintEmergencyQrTokenUseCaseProvider).call(ttlSeconds: _ttlSeconds);
    if (!mounted) return;
    result.fold(
      (m) {
        setState(() {
          _mint = m;
          _minting = false;
          _remaining = m.token.expiresAt.difference(DateTime.now());
        });
        _startTicker();
      },
      // Mint failures — incl. the age gate (FR-301b) — surface in the error
      // style below the mint affordance.
      (f) => setState(() {
        _minting = false;
        _error = f.message;
      }),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final m = _mint;
      if (m == null) {
        _ticker?.cancel();
        return;
      }
      setState(() => _remaining = m.token.expiresAt.difference(DateTime.now()));
    });
  }

  /// Revokes the active token → the public resolve endpoint returns 410. On
  /// success the QR clears and the sheet returns to the mint affordance.
  Future<void> _revoke() async {
    final m = _mint;
    if (m == null) return;
    setState(() => _revoking = true);
    final result = await ref.read(revokeEmergencyQrTokenUseCaseProvider).call(tokenId: m.token.jti);
    if (!mounted) return;
    result.fold(
      (_) {
        _ticker?.cancel();
        setState(() {
          _mint = null;
          _revoking = false;
          _error = null;
        });
        _showToast(s.strings.emergency.eqr_revoked_toast);
      },
      (f) => setState(() {
        _revoking = false;
        _error = f.message;
      }),
    );
  }

  /// Copies the full QR URL (incl. the `#k=` fragment) to the clipboard. This is
  /// a local share only — the key still never reaches the server.
  void _copy() {
    final m = _mint;
    if (m == null) return;
    Clipboard.setData(ClipboardData(text: m.qrUrl));
    _showToast(s.strings.emergency.eqr_link_copied);
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
    // Gate: can we mint? Need a signed-in user AND on-device health data.
    final userId = ref.watch(currentUserIdProvider);
    final snapAsync = ref.watch(_emergencySnapshotProvider);
    final snapshot = snapAsync.valueOrNull;
    final canShare = userId != null && snapshot != null && snapshot.hasAnyData;
    final loadingSnapshot = userId != null && snapAsync.isLoading;
    final hasToken = _mint != null;

    final String desc;
    if (hasToken) {
      desc = s.strings.emergency.eqr_help_active;
    } else if (userId == null) {
      desc = s.strings.emergency.eqr_help_signin;
    } else if (!canShare) {
      desc = s.strings.emergency.eqr_help_incomplete;
    } else {
      desc = s.strings.emergency.eqr_help_create;
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration:
          const BoxDecoration(color: T.cream50, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Stack(children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(children: [
              Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                      child: Text(s.strings.emergency.eqr_title,
                          style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700))),
                  RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
                ]),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 22 + MediaQuery.of(context).padding.bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(desc, style: Typo.bodySm(ar: ar).copyWith(color: T.fg3, height: 1.5)),
                ),
                if (hasToken)
                  ..._activeToken()
                else if (loadingSnapshot)
                  ..._loadingState()
                else if (!canShare)
                  ..._disabledState(signedOut: userId == null)
                else
                  ..._mintAffordance(),
              ]),
            ),
          ),
        ]),
        // In-sheet toast (matches the prototype's slide-up confirmation).
        if (toast != null)
          PositionedDirectional(
            start: 20,
            end: 20,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: RiseIn(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: T.ink900, borderRadius: BorderRadius.circular(T.rLg)),
              child: Row(children: [
                const Icon(LucideIcons.checkCircle, size: 18, color: T.petalMint),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(toast!,
                        style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: Colors.white))),
              ]),
            )),
          ),
      ]),
    );
  }

  /// The rounded-dot QR card with the flower center (prototype look). [dim]
  /// greys it once the token has expired.
  Widget _qrCard(String data, {bool dim = false}) => Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rXl),
            border: Border.all(color: T.ink100),
            boxShadow: T.shadowMd),
        child: Column(children: [
          Opacity(
            opacity: dim ? 0.3 : 1,
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(alignment: Alignment.center, children: [
                QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 240,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  // High EC so the centered flower stays scannable.
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: T.ink900),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: T.ink900),
                ),
                // Center flower mark with white halo (clears QR dots).
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 5)]),
                  child: const BalsmFlower(size: 42),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          if (widget.name.isNotEmpty)
            Text(widget.name,
                textAlign: TextAlign.center, style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // Expiry chip (replaces the prototype's static @handle line).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: _isExpired ? T.dangerBg : s.accent.bg, borderRadius: BorderRadius.circular(T.rPill)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isExpired ? LucideIcons.timerOff : LucideIcons.timer,
                  size: 15, color: _isExpired ? T.danger : s.accent.d),
              const SizedBox(width: 6),
              Text(
                _isExpired ? _countdownLabel : s.strings.emergency.eqr_expires_in(_countdownLabel),
                style: Typo.num(size: FS.xs, weight: FontWeight.w700, color: _isExpired ? T.danger : s.accent.d),
              ),
            ]),
          ),
        ]),
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
            color: Colors.white, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.ink100)),
        child: Row(children: [
          const Icon(LucideIcons.link, size: 16, color: T.fg3),
          const SizedBox(width: 10),
          Expanded(
              child: Text(m.qrUrl.split('#').first,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.num(size: FS.sm, color: T.fg2))),
          PButton(s.strings.emergency.eqr_copy,
              icon: LucideIcons.copy,
              variant: BtnVariant.ghost,
              accent: s.accent,
              ar: ar,
              onTap: expired ? null : _copy),
        ]),
      ),
      const SizedBox(height: 16),
      if (expired)
        // Token lapsed → offer a fresh mint (returns to the affordance).
        PButton(s.strings.emergency.eqr_generate_new,
            icon: LucideIcons.refreshCw,
            variant: BtnVariant.primary,
            large: true,
            block: true,
            accent: s.accent,
            ar: ar, onTap: () {
          _ticker?.cancel();
          setState(() => _mint = null);
        })
      else ...[
        Row(children: [
          Expanded(
              child: PButton(s.strings.emergency.eqr_save,
                  icon: LucideIcons.download,
                  variant: BtnVariant.secondary,
                  large: true,
                  block: true,
                  ar: ar,
                  onTap: () => _showToast(s.strings.emergency.eqr_saved_toast))),
          const SizedBox(width: 10),
          Expanded(
              child: PButton(s.strings.emergency.eqr_share,
                  icon: LucideIcons.share2,
                  variant: BtnVariant.primary,
                  large: true,
                  block: true,
                  accent: s.accent,
                  ar: ar,
                  onTap: _copy)),
        ]),
        const SizedBox(height: 10),
        _revoking
            ? _busyButton()
            : PButton(s.strings.emergency.eqr_revoke,
                icon: LucideIcons.ban, variant: BtnVariant.ghost, block: true, ar: ar, color: T.danger, onTap: _revoke),
      ],
    ];
  }

  /// Pre-mint affordance: TTL picker + Generate, plus any mint error.
  List<Widget> _mintAffordance() => [
        Text(s.strings.emergency.eqr_valid_for.toUpperCase(),
            style: Typo.meta(ar: ar)
                .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, letterSpacing: ar ? 0 : 0.8, color: T.fg3)),
        const SizedBox(height: 8),
        _ttlControl(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _errorBox(_error!),
        ],
        const SizedBox(height: 16),
        _minting
            ? _busyButton(primary: true)
            : PButton(s.strings.emergency.eqr_generate,
                icon: LucideIcons.qrCode,
                variant: BtnVariant.primary,
                large: true,
                block: true,
                accent: s.accent,
                ar: ar,
                onTap: _mintToken),
      ];

  /// Segmented TTL selector (mirrors the prototype's `.segmented` control).
  Widget _ttlControl() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: T.ink50, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.border)),
        child: Row(children: [
          for (var i = 0; i < _emergencyTtlOptions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _ttlSeg(_emergencyTtlOptions[i])),
          ],
        ]),
      );

  Widget _ttlSeg(({String key, int seconds}) opt) {
    final active = _ttlSeconds == opt.seconds;
    return GestureDetector(
      onTap: () => setState(() => _ttlSeconds = opt.seconds),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.easeOut,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active ? T.shadowXs : null),
        child: Text(s.t(opt.key),
            style: Typo.num(size: FS.sm, weight: FontWeight.w700, color: active ? s.accent.d : T.fg3)),
      ),
    );
  }

  /// Disabled/empty state — signed out or no health data (never crashes).
  List<Widget> _disabledState({required bool signedOut}) => [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(T.rXl),
              border: Border.all(color: T.ink100),
              boxShadow: T.shadowSm),
          child: Column(children: [
            Icon(signedOut ? LucideIcons.lock : LucideIcons.heartPulse, size: 40, color: T.ink300),
            const SizedBox(height: 14),
            Text(signedOut ? s.strings.emergency.eqr_signin_required : s.strings.emergency.eqr_no_data,
                textAlign: TextAlign.center,
                style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
          ]),
        ),
        const SizedBox(height: 16),
        // Disabled Generate button (0.4 opacity, non-tappable) — prototype style.
        Opacity(
          opacity: 0.4,
          child: PButton(s.strings.emergency.eqr_generate,
              icon: LucideIcons.qrCode,
              variant: BtnVariant.primary,
              large: true,
              block: true,
              accent: s.accent,
              ar: ar,
              onTap: null),
        ),
      ];

  List<Widget> _loadingState() => [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 60),
          alignment: Alignment.center,
          child: Spinner(size: 26, stroke: 2.5, color: s.accent.main),
        ),
      ];

  /// Mint/revoke error surfaced in the prototype's error style (danger wash).
  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: T.dangerBg, borderRadius: BorderRadius.circular(T.rMd)),
        child: Row(children: [
          const Icon(LucideIcons.alertCircle, size: 18, color: T.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.danger))),
        ]),
      );

  /// Button-shaped busy indicator (PButton has no loading prop).
  Widget _busyButton({bool primary = false}) => Container(
        height: primary ? 56 : 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: primary ? s.accent.main : Colors.white,
            borderRadius: BorderRadius.circular(primary ? T.rLg : T.rMd),
            border: primary ? null : Border.all(color: T.borderStrong),
            boxShadow: primary ? s.accent.boxShadow : null),
        child: Spinner(size: 22, stroke: 2.5, color: primary ? Colors.white : s.accent.main),
      );
}
