import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:core/core.dart' show currentUserIdProvider;
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
        profileDaoProvider,
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
final _emergencyContactsProvider =
    FutureProvider.autoDispose<List<EmergencyContact>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final profile = await ref.watch(profileDaoProvider).getProfile(userId);
  return profile?.emergencyContacts ?? const [];
});

/// Reads the on-device [EmergencyCardSnapshot] via the Tier-0
/// `emergencySnapshotReaderProvider` seam (the same PHI the mint use-case
/// encrypts). Used only to gate the QR-share sheet's mint affordance: `null`
/// when signed out or when there is no profile yet. Never leaves the device.
final _emergencySnapshotProvider =
    FutureProvider.autoDispose<EmergencyCardSnapshot?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(emergencySnapshotReaderProvider).readSnapshot();
});

/// TTL choices offered before minting the emergency QR token (FR-017).
const _emergencyTtlOptions = <({String en, String ar, int seconds})>[
  (en: '1h', ar: 'ساعة', seconds: 3600),
  (en: '6h', ar: '٦ س', seconds: 21600),
  (en: '24h', ar: '٢٤ س', seconds: 86400),
  (en: '7d', ar: '٧ أيام', seconds: 604800),
];

class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key, required this.s});
  final PatientAppState s;
  @override
  ConsumerState<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends ConsumerState<PersonalDetailsScreen> {
  final handle = TextEditingController(text: 'layla_hassan58');
  final first = TextEditingController(text: 'Layla');
  final last = TextEditingController(text: 'Hassan');
  final dob = TextEditingController(text: '14 / 03 / 1967');
  final phone = TextEditingController(text: '+20 10 1234 5678');
  final nid = TextEditingController(text: '2 6703 14 12345 6');
  // Emergency-contact fields now feed the real AddEmergencyContactUseCase, so
  // they start empty (an "add new contact" form) rather than seeded sample PHI.
  final emName = TextEditingController();
  final emRel = TextEditingController();
  final emPhone = TextEditingController();
  String gender = 'female';
  bool connApple = false;
  bool connGoogle = false;
  bool saved = false;

  // Handle availability — validated before save (mirrors signup _UsernameField).
  static const _origHandle = 'layla_hassan58';
  static const _takenHandles = {
    'layla', 'hassan', 'balsm', 'admin', 'doctor', 'health', 'user', 'omar', 'sara', 'mona', 'ahmed',
  };
  String unStatus = 'idle'; // idle | checking | available | taken | invalid
  Timer? _debounce;

  PatientAppState get s => widget.s;

  /// Save is blocked while the handle is mid-check, taken, or malformed —
  /// only an unchanged ('idle') or 'available' handle may submit to the server.
  bool get _canSave => unStatus == 'idle' || unStatus == 'available';

  void _setHandle(String raw) {
    final v = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (handle.text != v) {
      handle.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    }
    _debounce?.cancel();
    if (v.isEmpty || v == _origHandle) { setState(() => unStatus = 'idle'); return; }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v)) { setState(() => unStatus = 'invalid'); return; }
    setState(() => unStatus = 'checking');
    _debounce = Timer(const Duration(milliseconds: 700),
        () { if (mounted) setState(() => unStatus = _takenHandles.contains(v) ? 'taken' : 'available'); });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return; // never submit an invalid / taken / unverified handle
    setState(() => saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => saved = false); });
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error.message)));
    }
  }

  /// Read-only styled row for an existing emergency contact (prototype look).
  Widget _contactRow(EmergencyContact c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Flexible(
                      child: Text(c.name,
                          style: Typo.body(ar: s.rtl).copyWith(
                              fontWeight: FontWeight.w700, color: T.fg1))),
                  if (c.isPrimary) ...[
                    const SizedBox(width: 7),
                    Pill(s.rtl ? 'أساسي' : 'Primary',
                        kind: PillKind.info,
                        dot: false,
                        ar: s.rtl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2)),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(
                  c.relation == null || c.relation!.isEmpty
                      ? c.phone
                      : '${c.relation} · ${c.phone}',
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
        'checking' => s.t('un_checking'),
        'available' => s.t('un_avail'),
        'taken' => s.t('un_taken'),
        'invalid' => s.t('un_invalid'),
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
    final contacts = ref.watch(_emergencyContactsProvider).valueOrNull ??
        const <EmergencyContact>[];
    final atMaxContacts =
        contacts.length >= AddEmergencyContactUseCase.maxContacts;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        const PadTop(),
        AppBarRow(
          leading: RoundBtn(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context)),
          children: [
            Expanded(child: Text(s.t('p_personal'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
            if (saved) ...[Pill(s.t('pd_saved'), kind: PillKind.success, ar: s.rtl), const SizedBox(width: 8)],
            RoundBtn(icon: LucideIcons.qrCode, iconSize: 19, onTap: () => _showQr(context)),
          ],
        ),
        Expanded(child: ContentColumn(maxWidth: 560, child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            // Avatar
            Center(child: Column(children: [
              Avatar(initials: '${first.text.isEmpty ? '' : first.text[0]}${last.text.isEmpty ? '' : last.text[0]}', color: T.petalAqua, size: 72),
              const SizedBox(height: 10),
              PButton(s.rtl ? 'تغيير الصورة' : 'Change photo', icon: LucideIcons.camera, variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl),
            ])),
            // Account (handle + QR share)
            _section(LucideIcons.atSign, s.t('pd_account')),
            _card([
              _labeled(s.t('un_label'), TextField(
                controller: handle, textDirection: TextDirection.ltr,
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
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd),
                      borderSide: BorderSide(color: unStatus == 'idle' ? T.border : _handleStatusColor, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd),
                      borderSide: BorderSide(color: unStatus == 'idle' ? s.accent.main : _handleStatusColor, width: 1.5)),
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
                            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: _handleStatusColor)),
                      ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(LucideIcons.link, size: 12, color: T.fg4),
                const SizedBox(width: 5),
                Text('balsm.health/@${handle.text}', textDirection: TextDirection.ltr, style: Typo.num(size: FS.xs, color: T.fg3)),
              ]),
              const SizedBox(height: 14),
              Pressable(
                onTap: () => _showQr(context),
                scale: 0.98,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
                  child: Row(children: [
                    Container(width: 38, height: 38, alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rSm)),
                        child: Icon(LucideIcons.qrCode, size: 20, color: s.accent.d)),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.t('pd_share_qr'), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
                      Text(s.t('pd_share_qr_h'), style: Typo.meta(ar: s.rtl).copyWith(color: s.accent.d)),
                    ])),
                    Chevron(rtl: s.rtl, color: s.accent.d),
                  ]),
                ),
              ),
            ]),
            // Connected accounts
            _section(LucideIcons.link, s.t('conn_accounts')),
            _ConnCard(s: s, apple: connApple, google: connGoogle,
                onApple: () => setState(() => connApple = !connApple), onGoogle: () => setState(() => connGoogle = !connGoogle)),
            // Basic info
            _section(LucideIcons.user, s.rtl ? 'المعلومات الأساسية' : 'Basic info'),
            _card([
              Row(children: [
                Expanded(child: _field(s.t('pf_fname'), first)),
                const SizedBox(width: 12),
                Expanded(child: _field(s.t('pf_lname'), last)),
              ]),
              const SizedBox(height: 14),
              _field(s.t('pf_dob'), dob, mono: true),
              const SizedBox(height: 14),
              _labeled(s.t('pf_gender'), _genderSeg()),
            ]),
            // Contact
            _section(LucideIcons.phone, s.rtl ? 'معلومات الاتصال' : 'Contact'),
            _card([
              _field(s.t('pd_phone'), phone, mono: true),
              const SizedBox(height: 14),
              _field(s.t('pd_nid'), nid, mono: true),
              const SizedBox(height: 14),
              _labeled(s.t('pd_nationality'), _selectField(s.t('nat_egyptian'))),
            ]),
            // Emergency contact (real on-device PHI; up to 3 contacts).
            _section(LucideIcons.phoneCall, s.t('pd_emergency')),
            _card([
              for (var i = 0; i < contacts.length; i++) ...[
                _contactRow(contacts[i]),
                if (i < contacts.length - 1 || !atMaxContacts)
                  const SizedBox(height: 12),
              ],
              if (!atMaxContacts) ...[
                _field(s.t('pd_em_name'), emName),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _field(s.t('pd_em_rel'), emRel)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(s.t('pd_em_phone'), emPhone, mono: true)),
                ]),
                const SizedBox(height: 14),
                PButton(s.rtl ? 'إضافة جهة اتصال' : 'Add contact',
                    icon: LucideIcons.plus, variant: BtnVariant.secondary,
                    block: true, accent: s.accent, ar: s.rtl,
                    onTap: _addEmergencyContact),
              ],
            ]),
            const SizedBox(height: 24),
            // Disabled until the handle is verified available (or unchanged).
            Opacity(
              opacity: _canSave ? 1 : 0.4,
              child: PButton(saved ? s.t('pd_saved') : s.t('pd_save'), icon: saved ? LucideIcons.check : LucideIcons.save,
                  variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl,
                  onTap: _canSave ? _save : null),
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
            child: _QrShareSheet(s: s, name: '${first.text} ${last.text}'.trim()),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.border), boxShadow: T.shadowSm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _labeled(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, letterSpacing: s.rtl ? 0 : 0.8, color: T.fg3)),
        const SizedBox(height: 8),
        child,
      ]);

  Widget _field(String label, TextEditingController c, {bool mono = false}) => _labeled(label, TextField(
        controller: c, textDirection: mono ? TextDirection.ltr : s.dir,
        style: mono ? Typo.num(size: FS.lg) : Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, color: T.fg1),
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      ));

  /// Dropdown-style read-only field (nationality).
  Widget _selectField(String value) => Container(
        height: 52, padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(T.rMd),
          border: Border.all(color: T.border, width: 1.5),
        ),
        child: Row(children: [
          Expanded(child: Text(value, style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, color: T.fg1))),
          const Icon(LucideIcons.chevronDown, size: 18, color: T.fg4),
        ]),
      );

  Widget _genderSeg() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.border)),
        child: Row(children: [
          _seg(s.t('pf_female'), gender == 'female', () => setState(() => gender = 'female')),
          const SizedBox(width: 6),
          _seg(s.t('pf_male'), gender == 'male', () => setState(() => gender = 'male')),
        ]),
      );

  // `.segmented button` — active pill bg/shadow animate over --dur-base.
  Widget _seg(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            height: 42, alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(7), boxShadow: active ? T.shadowXs : null),
            child: Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: active ? T.fg1 : T.fg3)),
          ),
        ),
      );
}

class _ConnCard extends StatelessWidget {
  const _ConnCard({required this.s, required this.apple, required this.google, required this.onApple, required this.onGoogle});
  final PatientAppState s;
  final bool apple, google;
  final VoidCallback onApple, onGoogle;
  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color iconBg, Color iconColor, String label, bool connected, VoidCallback onTap, bool last) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink100))),
          child: Row(children: [
            Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(T.rMd), border: iconBg == Colors.white ? Border.all(color: T.ink100) : null), child: Icon(icon, size: 19, color: iconColor)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1))),
            PButton(connected ? s.t('conn_remove') : s.t('conn_connect'), variant: connected ? BtnVariant.secondary : BtnVariant.soft, accent: s.accent, ar: s.rtl, onTap: onTap),
          ]),
        );
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.border), boxShadow: T.shadowSm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rLg),
        child: Column(children: [
          row(Icons.apple, const Color(0xFF1A1A17), Colors.white, s.t('conn_apple'), apple, onApple, false),
          row(LucideIcons.chrome, Colors.white, const Color(0xFF4285F4), s.t('conn_google'), google, onGoogle, true),
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

  bool get _isExpired =>
      _mint == null || _remaining.isNegative || _remaining == Duration.zero;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _showToast(String msg) {
    setState(() => toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800),
        () { if (mounted) setState(() => toast = null); });
  }

  /// Mints the real emergency token. The use-case reads the on-device snapshot
  /// via the Tier-0 seam, client-side AES-256-GCM encrypts it, POSTs ONLY the
  /// ciphertext, and returns the full QR URL with the key in the `#k=` fragment.
  Future<void> _mintToken() async {
    setState(() { _minting = true; _error = null; });
    final result = await ref
        .read(mintEmergencyQrTokenUseCaseProvider)
        .call(ttlSeconds: _ttlSeconds);
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
      (f) => setState(() { _minting = false; _error = f.message; }),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final m = _mint;
      if (m == null) { _ticker?.cancel(); return; }
      setState(() => _remaining = m.token.expiresAt.difference(DateTime.now()));
    });
  }

  /// Revokes the active token → the public resolve endpoint returns 410. On
  /// success the QR clears and the sheet returns to the mint affordance.
  Future<void> _revoke() async {
    final m = _mint;
    if (m == null) return;
    setState(() => _revoking = true);
    final result = await ref
        .read(revokeEmergencyQrTokenUseCaseProvider)
        .call(tokenId: m.token.jti);
    if (!mounted) return;
    result.fold(
      (_) {
        _ticker?.cancel();
        setState(() { _mint = null; _revoking = false; _error = null; });
        _showToast(ar ? 'تم إلغاء الرمز' : 'QR revoked');
      },
      (f) => setState(() { _revoking = false; _error = f.message; }),
    );
  }

  /// Copies the full QR URL (incl. the `#k=` fragment) to the clipboard. This is
  /// a local share only — the key still never reaches the server.
  void _copy() {
    final m = _mint;
    if (m == null) return;
    Clipboard.setData(ClipboardData(text: m.qrUrl));
    _showToast(ar ? 'تم نسخ الرابط' : 'Link copied');
  }

  String get _countdownLabel {
    if (_isExpired) return ar ? 'منتهي' : 'Expired';
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
      desc = ar
          ? 'اعرض هذا الرمز المشفّر لطاقم الطوارئ. ينتهي تلقائيًا ولا يحتوي على مفتاح فك التشفير إلا داخل الرابط نفسه.'
          : 'Show this encrypted code to emergency staff. It expires automatically; the decryption key travels only inside the link.';
    } else if (userId == null) {
      desc = ar
          ? 'سجّل الدخول لمشاركة بطاقة الطوارئ الصحية الخاصة بك.'
          : 'Sign in to share your emergency health card.';
    } else if (!canShare) {
      desc = ar
          ? 'أضف فصيلة دمك أو الحساسية أو الحالات أو جهة اتصال للطوارئ لمشاركة بطاقة الطوارئ.'
          : 'Add your blood type, allergies, conditions or an emergency contact to share an emergency card.';
    } else {
      desc = ar
          ? 'أنشئ رمز QR مشفّرًا لملفك الصحي للطوارئ. يبقى مفتاح فك التشفير على جهازك.'
          : 'Generate a secure, encrypted QR of your emergency health profile. The decryption key stays on your device.';
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(color: T.cream50, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Stack(children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(children: [
              Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(ar ? 'رمز الطوارئ' : 'Emergency QR',
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
            start: 20, end: 20, bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: RiseIn(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: T.ink900, borderRadius: BorderRadius.circular(T.rLg)),
              child: Row(children: [
                const Icon(LucideIcons.checkCircle, size: 18, color: T.petalMint),
                const SizedBox(width: 10),
                Expanded(child: Text(toast!, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: Colors.white))),
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
          color: Colors.white, borderRadius: BorderRadius.circular(T.rXl),
          border: Border.all(color: T.ink100), boxShadow: T.shadowMd),
        child: Column(children: [
          Opacity(
            opacity: dim ? 0.3 : 1,
            child: SizedBox(
              width: 240, height: 240,
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
                  width: 58, height: 58, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 5)]),
                  child: const BalsmFlower(size: 42),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          if (widget.name.isNotEmpty)
            Text(widget.name, textAlign: TextAlign.center,
                style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // Expiry chip (replaces the prototype's static @handle line).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _isExpired ? T.dangerBg : s.accent.bg,
              borderRadius: BorderRadius.circular(T.rPill)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isExpired ? LucideIcons.timerOff : LucideIcons.timer,
                  size: 15, color: _isExpired ? T.danger : s.accent.d),
              const SizedBox(width: 6),
              Text(
                _isExpired
                    ? _countdownLabel
                    : '${ar ? 'ينتهي خلال' : 'Expires in'} $_countdownLabel',
                style: Typo.num(size: FS.xs, weight: FontWeight.w700,
                    color: _isExpired ? T.danger : s.accent.d),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.ink100)),
        child: Row(children: [
          const Icon(LucideIcons.link, size: 16, color: T.fg3),
          const SizedBox(width: 10),
          Expanded(child: Text(m.qrUrl.split('#').first, textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Typo.num(size: FS.sm, color: T.fg2))),
          PButton(ar ? 'نسخ' : 'Copy', icon: LucideIcons.copy, variant: BtnVariant.ghost, accent: s.accent, ar: ar,
              onTap: expired ? null : _copy),
        ]),
      ),
      const SizedBox(height: 16),
      if (expired)
        // Token lapsed → offer a fresh mint (returns to the affordance).
        PButton(ar ? 'إنشاء رمز جديد' : 'Generate new code', icon: LucideIcons.refreshCw,
            variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: ar,
            onTap: () { _ticker?.cancel(); setState(() => _mint = null); })
      else ...[
        Row(children: [
          Expanded(child: PButton(ar ? 'حفظ' : 'Save', icon: LucideIcons.download, variant: BtnVariant.secondary, large: true, block: true, ar: ar,
              onTap: () => _showToast(ar ? 'تم حفظ الصورة' : 'Saved to Photos'))),
          const SizedBox(width: 10),
          Expanded(child: PButton(ar ? 'مشاركة' : 'Share', icon: LucideIcons.share2, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: ar,
              onTap: _copy)),
        ]),
        const SizedBox(height: 10),
        _revoking
            ? _busyButton()
            : PButton(ar ? 'إلغاء الرمز' : 'Revoke code', icon: LucideIcons.ban,
                variant: BtnVariant.ghost, block: true, ar: ar, color: T.danger, onTap: _revoke),
      ],
    ];
  }

  /// Pre-mint affordance: TTL picker + Generate, plus any mint error.
  List<Widget> _mintAffordance() => [
        Text((ar ? 'مدة الصلاحية' : 'Valid for').toUpperCase(),
            style: Typo.meta(ar: ar).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, letterSpacing: ar ? 0 : 0.8, color: T.fg3)),
        const SizedBox(height: 8),
        _ttlControl(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _errorBox(_error!),
        ],
        const SizedBox(height: 16),
        _minting
            ? _busyButton(primary: true)
            : PButton(ar ? 'إنشاء رمز QR' : 'Generate QR', icon: LucideIcons.qrCode,
                variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: ar,
                onTap: _mintToken),
      ];

  /// Segmented TTL selector (mirrors the prototype's `.segmented` control).
  Widget _ttlControl() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.border)),
        child: Row(children: [
          for (var i = 0; i < _emergencyTtlOptions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _ttlSeg(_emergencyTtlOptions[i])),
          ],
        ]),
      );

  Widget _ttlSeg(({String en, String ar, int seconds}) opt) {
    final active = _ttlSeconds == opt.seconds;
    return GestureDetector(
      onTap: () => setState(() => _ttlSeconds = opt.seconds),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.easeOut,
        height: 42, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active ? T.shadowXs : null),
        child: Text(ar ? opt.ar : opt.en,
            style: Typo.num(size: FS.sm, weight: FontWeight.w700,
                color: active ? s.accent.d : T.fg3)),
      ),
    );
  }

  /// Disabled/empty state — signed out or no health data (never crashes).
  List<Widget> _disabledState({required bool signedOut}) => [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(T.rXl),
            border: Border.all(color: T.ink100), boxShadow: T.shadowSm),
          child: Column(children: [
            Icon(signedOut ? LucideIcons.lock : LucideIcons.heartPulse,
                size: 40, color: T.ink300),
            const SizedBox(height: 14),
            Text(
              signedOut
                  ? (ar ? 'يلزم تسجيل الدخول' : 'Sign in required')
                  : (ar ? 'لا توجد بيانات صحية بعد' : 'No health data yet'),
              textAlign: TextAlign.center,
              style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
          ]),
        ),
        const SizedBox(height: 16),
        // Disabled Generate button (0.4 opacity, non-tappable) — prototype style.
        Opacity(
          opacity: 0.4,
          child: PButton(ar ? 'إنشاء رمز QR' : 'Generate QR', icon: LucideIcons.qrCode,
              variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: ar, onTap: null),
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
          Expanded(child: Text(msg,
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.danger))),
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
