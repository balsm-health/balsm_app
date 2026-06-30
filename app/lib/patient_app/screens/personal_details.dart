import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;

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

  PatientAppState get s => widget.s;

  void _save() {
    setState(() => saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => saved = false); });
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
                onChanged: (_) => setState(() {}),
                style: Typo.num(size: FS.lg),
                decoration: InputDecoration(
                  isDense: true, prefixText: '@',
                  prefixStyle: Typo.num(size: FS.lg, weight: FontWeight.w700, color: T.fg3),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
                ),
              )),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(LucideIcons.link, size: 12, color: T.fg4),
                const SizedBox(width: 5),
                Text('balsm.health/@${handle.text}', textDirection: TextDirection.ltr, style: Typo.num(size: FS.xs, color: T.fg3)),
              ]),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _showQr(context),
                behavior: HitTestBehavior.opaque,
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
            PButton(saved ? s.t('pd_saved') : s.t('pd_save'), icon: saved ? LucideIcons.check : LucideIcons.save,
                variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _save),
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
      barrierColor: const Color(0x5C2B2B25),
      builder: (ctx) => Directionality(
        textDirection: s.dir,
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
          padding: EdgeInsets.only(bottom: 40 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 18),
            Text(s.t('pd_share_qr'), style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.border, width: 1.5), boxShadow: T.shadowSm),
              child: QrImageView(
                data: 'balsm.health/@${handle.text}',
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: T.ink900),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: T.ink900),
              ),
            ),
            const SizedBox(height: 16),
            Text('@${handle.text}', textDirection: TextDirection.ltr, style: Typo.num(size: FS.lg, weight: FontWeight.w700, color: T.fg1)),
            const SizedBox(height: 2),
            Text('balsm.health/@${handle.text}', textDirection: TextDirection.ltr, style: Typo.num(size: FS.xs, color: T.fg3)),
            const SizedBox(height: 10),
            Text(s.t('pd_qr_scan'), style: Typo.meta(ar: s.rtl)),
          ]),
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

  Widget _seg(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
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
