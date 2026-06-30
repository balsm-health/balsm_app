import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key, required this.s});
  final PatientAppState s;
  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final handle = TextEditingController(text: 'layla_hassan58');
  final first = TextEditingController(text: 'Layla');
  final last = TextEditingController(text: 'Hassan');
  final dob = TextEditingController(text: '14 / 03 / 1967');
  final phone = TextEditingController(text: '+20 10 1234 5678');
  final nid = TextEditingController(text: '2 6703 14 12345 6');
  final emName = TextEditingController(text: 'Ahmed Hassan');
  final emRel = TextEditingController(text: 'Son');
  final emPhone = TextEditingController(text: '+20 10 9876 5432');
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
            // Emergency contact
            _section(LucideIcons.phoneCall, s.t('pd_emergency')),
            _card([
              _field(s.t('pd_em_name'), emName),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field(s.t('pd_em_rel'), emRel)),
                const SizedBox(width: 12),
                Expanded(child: _field(s.t('pd_em_phone'), emPhone, mono: true)),
              ]),
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
            child: _QrShareSheet(s: s, handle: handle.text, name: '${first.text} ${last.text}'.trim()),
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

/// Shareable patient QR (qrshare.jsx `QRShareSheet`): a rounded-dot QR with the
/// Balsm flower in its center, the patient name + handle, a copyable link row,
/// and Save / Share actions. Slides up; in-sheet toast confirms copy/save.
class _QrShareSheet extends StatefulWidget {
  const _QrShareSheet({required this.s, required this.handle, required this.name});
  final PatientAppState s;
  final String handle;
  final String name;
  @override
  State<_QrShareSheet> createState() => _QrShareSheetState();
}

class _QrShareSheetState extends State<_QrShareSheet> {
  String? toast;
  Timer? _toastTimer;

  PatientAppState get s => widget.s;
  bool get ar => s.rtl;
  String get url => 'balsm.health/@${widget.handle}';

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String msg) {
    setState(() => toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () { if (mounted) setState(() => toast = null); });
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: 'https://$url'));
    _showToast(ar ? 'تم نسخ الرابط' : 'Link copied');
  }

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: Text(ar ? 'رمز المشاركة' : 'My QR code',
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
                  child: Text(
                    ar ? 'امسح هذا الرمز لمشاركة ملفك الصحي بأمان مع طبيبك أو عائلتك.'
                       : 'Scan this code to securely share your health profile with a doctor or family member.',
                    style: Typo.bodySm(ar: ar).copyWith(color: T.fg3, height: 1.5)),
                ),
                // QR card
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(T.rXl),
                    border: Border.all(color: T.ink100), boxShadow: T.shadowMd),
                  child: Column(children: [
                    SizedBox(
                      width: 240, height: 240,
                      child: Stack(alignment: Alignment.center, children: [
                        QrImageView(
                          data: 'https://$url',
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
                    const SizedBox(height: 18),
                    if (widget.name.isNotEmpty)
                      Text(widget.name, textAlign: TextAlign.center,
                          style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('@${widget.handle}', textDirection: TextDirection.ltr,
                        style: Typo.num(size: FS.sm, weight: FontWeight.w600, color: s.accent.main)),
                  ]),
                ),
                const SizedBox(height: 16),
                // Link row + copy
                Container(
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 6, top: 6, bottom: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.ink100)),
                  child: Row(children: [
                    const Icon(LucideIcons.link, size: 16, color: T.fg3),
                    const SizedBox(width: 10),
                    Expanded(child: Text(url, textDirection: TextDirection.ltr, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Typo.num(size: FS.sm, color: T.fg2))),
                    PButton(ar ? 'نسخ' : 'Copy', icon: LucideIcons.copy, variant: BtnVariant.ghost, accent: s.accent, ar: ar, onTap: _copy),
                  ]),
                ),
                const SizedBox(height: 16),
                // Actions
                Row(children: [
                  Expanded(child: PButton(ar ? 'حفظ' : 'Save', icon: LucideIcons.download, variant: BtnVariant.secondary, large: true, block: true, ar: ar,
                      onTap: () => _showToast(ar ? 'تم حفظ الصورة' : 'Saved to Photos'))),
                  const SizedBox(width: 10),
                  Expanded(child: PButton(ar ? 'مشاركة' : 'Share', icon: LucideIcons.share2, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: ar,
                      onTap: _copy)),
                ]),
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
}
