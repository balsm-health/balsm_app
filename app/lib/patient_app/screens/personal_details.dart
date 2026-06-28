import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;

/// Opens the health profile editor (home.jsx PersonalDetailsScreen).
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
  final first = TextEditingController(text: 'Layla');
  final last = TextEditingController(text: 'Hassan');
  final dob = TextEditingController(text: '14 / 03 / 1967');
  final phone = TextEditingController(text: '+20 10 1234 5678');
  final nid = TextEditingController(text: '2 6703 14 12345 6');
  final emName = TextEditingController(text: 'Ahmed Hassan');
  final emRel = TextEditingController(text: 'Son');
  final emPhone = TextEditingController(text: '+20 10 9876 5432');
  String gender = 'female';
  String blood = 'B+';
  final weight = TextEditingController(text: '78');
  final height = TextEditingController(text: '162');
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
            if (saved) Pill(s.t('pd_saved'), kind: PillKind.success, ar: s.rtl),
          ],
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            // Avatar
            Center(child: Column(children: [
              Avatar(initials: '${first.text.isEmpty ? '' : first.text[0]}${last.text.isEmpty ? '' : last.text[0]}', color: T.petalAqua, size: 72),
              const SizedBox(height: 10),
              PButton(s.rtl ? 'تغيير الصورة' : 'Change photo', icon: LucideIcons.camera, variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl),
            ])),
            _section(LucideIcons.link, s.t('conn_accounts')),
            _ConnCard(s: s, apple: connApple, google: connGoogle,
                onApple: () => setState(() => connApple = !connApple), onGoogle: () => setState(() => connGoogle = !connGoogle)),
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
            _section(LucideIcons.phone, s.rtl ? 'معلومات الاتصال' : 'Contact'),
            _card([
              _field(s.t('pd_phone'), phone, mono: true),
              const SizedBox(height: 14),
              _field(s.t('pd_nid'), nid, mono: true),
            ]),
            _section(LucideIcons.heartPulse, s.rtl ? 'المعلومات الطبية' : 'Medical'),
            _card([
              _labeled(s.t('pd_blood'), Wrap(spacing: 8, runSpacing: 8, children: [
                for (final bt in const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']) _bloodChip(bt),
              ])),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field('${s.t('pd_weight')} (kg)', weight, mono: true)),
                const SizedBox(width: 12),
                Expanded(child: _field('${s.t('pd_height')} (cm)', height, mono: true)),
              ]),
            ]),
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
        )),
      ]),
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

  Widget _bloodChip(String bt) => GestureDetector(
        onTap: () => setState(() => blood = bt),
        child: Container(
          height: 40, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
          decoration: BoxDecoration(
            color: blood == bt ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: blood == bt ? s.accent.main : T.border, width: 1.5),
          ),
          child: Text(bt, style: Typo.num(size: FS.sm, weight: FontWeight.w700, color: blood == bt ? s.accent.d : T.fg2)),
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
