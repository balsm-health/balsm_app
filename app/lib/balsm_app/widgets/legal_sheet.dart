import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart' show countryRegistryProvider;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:disclosure/disclosure.dart' show disclosureStrings, disclosureMessagesOf;
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Which half of the notice a sheet shows (settings.jsx `LegalSheet`'s `kind`).
enum LegalKind { terms, privacy }

/// Version of the consolidated notice this build enforces — kept in step with
/// the disclosure gate in `auth_flow.dart` so the footer never claims a
/// revision the user was not actually asked to accept.
const String kLegalNoticeVersion = '1';

/// Terms / privacy sheet reachable from the auth footer.
///
/// The copy is NOT written here: it is the same reviewed consolidated-disclosure
/// text the post-sign-in gate shows, read from the `disclosure` module. `terms`
/// covers what the patient agrees to (rights, sharing, deletion); `privacy`
/// covers what is held and how (collection, protection, supervisory authority).
Future<void> showLegalSheet(BuildContext context, LegalKind kind) async {
  final s = AppScope.of(context);
  // Arabic is a deferred library in the disclosure module — load before render
  // so the sheet never flashes English.
  await disclosureStrings.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C14202B),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _LegalSheet(s: s, kind: kind),
        ),
      ),
    ),
  );
}

class _LegalSheet extends ConsumerWidget {
  const _LegalSheet({required this.s, required this.kind});
  final PatientAppState s;
  final LegalKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = s.rtl;
    final m = disclosureMessagesOf(s.lang.value).section;
    // The complaints body names the regulator for the patient's country.
    final authority = ref.watch(countryRegistryProvider).supervisoryAuthority(s.country.value);
    final sections = switch (kind) {
      LegalKind.terms => [
          (m.yourRights.title, m.yourRights.body),
          (m.sharing.title, m.sharing.body),
          (m.deletion.title, m.deletion.body),
        ],
      LegalKind.privacy => [
          (m.dataCollected.title, m.dataCollected.body),
          (m.howProtected.title, m.howProtected.body),
          (m.supervisory.title, m.supervisory.body(authority)),
        ],
    };
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration:
          const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
            width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(
                child: Text(kind == LegalKind.terms ? s.strings.auth.legal_terms_t : s.strings.auth.legal_priv_t,
                    style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
            children: [
              for (final (i, sec) in sections.indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: i < sections.length - 1 ? 22 : 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sec.$1, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                    const SizedBox(height: 6),
                    Text(sec.$2, style: Typo.bodySm(ar: ar).copyWith(height: 1.65)),
                  ]),
                ),
              const Padding(padding: EdgeInsets.only(top: 10), child: Divider(height: 1, color: T.ink100)),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${s.strings.auth.legal_updated} '),
                    TextSpan(text: kLegalNoticeVersion, style: Typo.num(size: FS.xs2, color: T.fg3)),
                  ]),
                  style: Typo.meta(ar: ar).copyWith(fontSize: FS.xs2),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// `TermsLine` — the consent sentence with tappable terms / privacy links.
class TermsLine extends StatefulWidget {
  const TermsLine({super.key, required this.s});
  final PatientAppState s;
  @override
  State<TermsLine> createState() => _TermsLineState();
}

class _TermsLineState extends State<TermsLine> {
  // Recognizers own a gesture arena entry each, so they are built once and
  // disposed with the widget rather than per frame.
  late final _terms = TapGestureRecognizer()..onTap = () => showLegalSheet(context, LegalKind.terms);
  late final _privacy = TapGestureRecognizer()..onTap = () => showLegalSheet(context, LegalKind.privacy);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final a = s.strings.auth;
    final base = Typo.meta(ar: s.rtl).copyWith(height: 1.5);
    final link = base.copyWith(
      color: s.accent.d,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: s.accent.d,
    );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '${a.ph_terms_pre} '),
        TextSpan(text: a.ph_terms_link, style: link, recognizer: _terms),
        TextSpan(text: ' ${a.ph_terms_and} '),
        TextSpan(text: a.ph_priv_link, style: link, recognizer: _privacy),
        const TextSpan(text: '.'),
      ]),
      textAlign: TextAlign.center,
      style: base,
    );
  }
}
