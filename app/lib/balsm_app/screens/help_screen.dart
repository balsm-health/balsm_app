import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'profile_subscreens.dart';

/// Profile › Help & support (help.jsx HelpSupportScreen).
///
/// Ported where the app can honour it: the not-an-emergency-service notice
/// (with the account country's own ambulance number, tap to call), common
/// questions whose answers describe what this build actually does, and the
/// support mailbox. The design's in-app "Report a problem" form is not ported:
/// it promises an email reply, and the only in-app channel (Sentry feedback)
/// never carries the patient's email. Its GitHub row and version footer are
/// left out too — the ecosystem sheet already links the community.
void openHelpSupport(BuildContext context) => pushSubScreen(context, (s) => HelpSupportScreen(s: s));

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, required this.s});
  final PatientAppState s;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  /// The one expanded question, or null — the design opens one at a time.
  int? _open;

  PatientAppState get s => widget.s;

  List<(String, String)> get _faq {
    final h = s.strings.help;
    return [
      (h.hp_q_data, h.hp_a_data),
      (h.hp_q_offline, h.hp_a_offline),
      (h.hp_q_password, h.hp_a_password(s.gender)),
      (h.hp_q_delete, h.hp_a_delete),
    ];
  }

  Future<void> _emailUs() async {
    final uri = Uri(scheme: 'mailto', path: StatusScreen.supportEmail);
    if (!await launchUrl(uri)) await Clipboard.setData(const ClipboardData(text: StatusScreen.supportEmail));
  }

  @override
  Widget build(BuildContext context) {
    final h = s.strings.help;
    final faq = _faq;
    return SubScreen(
      s: s,
      title: s.strings.profile.p_help,
      children: [
        const SizedBox(height: 4),
        _EmergencyNotice(s: s),
        _Section(LucideIcons.circleHelp, h.hp_faq, s: s),
        _card(faq.indexed.map((e) => _faqRow(e.$1, e.$2.$1, e.$2.$2, last: e.$1 == faq.length - 1)).toList()),
        _Section(LucideIcons.messageCircle, h.hp_contact, s: s),
        _card([_emailRow(h.hp_email(s.gender))]),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text('Balsm.health · ${h.hp_open_source}',
              textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg4)),
        ),
      ],
    );
  }

  Widget _card(List<Widget> rows) => PCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(borderRadius: BorderRadius.circular(T.rLg), child: Column(children: rows)),
      );

  Widget _faqRow(int i, String q, String a, {required bool last}) {
    final on = _open == i;
    return Container(
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink100))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          expanded: on,
          child: InkWell(
            onTap: () => setState(() => _open = on ? null : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Text(q,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1, height: 1.4)),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: on ? 0.5 : 0,
                  duration: Motion.fast,
                  curve: Motion.easeOut,
                  child: const Icon(LucideIcons.chevronDown, size: 18, color: T.fg3),
                ),
              ]),
            ),
          ),
        ),
        if (on)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            child: Text(a, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2, height: 1.6)),
          ),
      ]),
    );
  }

  Widget _emailRow(String title) => Pressable(
        onTap: _emailUs,
        scale: 0.99,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
              child: const Icon(LucideIcons.mail, size: 18, color: T.fg2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                const SizedBox(height: 2),
                const Text(StatusScreen.supportEmail,
                    textDirection: TextDirection.ltr, style: TextStyle(fontSize: FS.xs, color: T.fg3)),
              ]),
            ),
            const Icon(LucideIcons.externalLink, size: 16, color: T.fg3),
          ]),
        ),
      );
}

/// `--balsm-danger-bg` notice: Balsm is not an emergency service. The number
/// is the account country's ambulance line, tap to call; a country without one
/// on record gets the generic "your local emergency number" line instead.
class _EmergencyNotice extends StatelessWidget {
  const _EmergencyNotice({required this.s});
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    final h = s.strings.help;
    final number = s.country.emergencyNumber;
    final style = Typo.bodySm(ar: s.rtl).copyWith(color: T.fg1, height: 1.5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: T.dangerBg, borderRadius: BorderRadius.circular(T.rLg)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.siren, size: 20, color: T.danger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: number.isEmpty
              ? Text(h.hp_emergency_local(s.gender), style: style)
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${h.hp_emergency_on(s.gender)} '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => launchUrl(Uri(scheme: 'tel', path: number)),
                          child: Text(number,
                              textDirection: TextDirection.ltr,
                              style: style.copyWith(fontWeight: FontWeight.w700, color: T.danger)),
                        ),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ]),
                  style: style,
                ),
        ),
      ]),
    );
  }
}

/// Section label with an accent icon, as on Privacy & data.
class _Section extends StatelessWidget {
  const _Section(this.icon, this.title, {required this.s});
  final IconData icon;
  final String title;
  final PatientAppState s;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
        child: Row(children: [
          Icon(icon, size: 16, color: s.accent.main),
          const SizedBox(width: 8),
          Text(title, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        ]),
      );
}
