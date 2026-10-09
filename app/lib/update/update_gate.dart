import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:core/core.dart';

import '../balsm_app/kit.dart';
import '../balsm_app/tokens.dart';
import 'release_notes_html.dart';

/// The words on the update sheet. A plain value so the sheet belongs to no
/// brand's string bundle: each app shell fills it from its own, with its own
/// product name.
@immutable
class UpdateCopy {
  const UpdateCopy({
    required this.eyebrowNew,
    required this.eyebrowRequired,
    required this.availableTitle,
    required this.availableBody,
    required this.requiredTitle,
    required this.requiredBody,
    required this.current,
    required this.newVersion,
    required this.whatsNew,
    required this.updateNow,
    required this.skip,
    required this.fullNotes,
    required this.close,
  });
  final String eyebrowNew;
  final String eyebrowRequired;
  final String availableTitle;
  final String availableBody;
  final String requiredTitle;
  final String requiredBody;
  final String current;
  final String newVersion;
  final String whatsNew;
  final String updateNow;
  final String skip;

  /// The link to the release-notes web page.
  final String fullNotes;

  /// Screen-reader label for the close button.
  final String close;
}

/// How the sheet is dressed for the app showing it: language direction,
/// accent, words, and the brand mark at the top.
@immutable
class UpdateLook {
  const UpdateLook({required this.rtl, required this.accent, required this.copy, required this.mark});
  final bool rtl;
  final Accent accent;
  final UpdateCopy copy;

  /// The brand's mark, sized by the caller (52px in the design).
  final Widget mark;
}

/// Checks for a newer app version on launch and on every return to the
/// foreground, and raises the design's update sheet (`update.jsx`) over the
/// app:
///
///  * [UpdateStatus.available] — skippable. Close hides it until the next
///    launch; "Skip this version" silences it until a newer release.
///  * [UpdateStatus.required] — blocking: no close, no skip, and the scrim does
///    not dismiss. A newer release is forced, or this build is below the
///    minimum.
///
/// Brand-neutral: it reads [brand]'s own manifest and takes its words, accent
/// and mark from [look], so every app shell (Balsm, Balsm Pro, …) mounts the
/// same gate with its own values and depends on no other shell's state.
///
/// Mount it in `MaterialApp.builder`, above the navigator, so no route or
/// sheet can cover a required update.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    required this.brand,
    required this.lang,
    required this.look,
    this.prefs,
    this.cached,
    this.check,
  });
  final Widget child;

  /// Whose manifest to read.
  final AppBrand brand;

  /// The language release notes should be in (`en`, `ar`).
  final String lang;
  final UpdateLook look;

  /// Where the last manifest and the skipped version are kept. Null (tests,
  /// or before storage is up) runs no check unless [check] is given.
  final AppUpdatePrefs? prefs;

  /// Overrides for tests; default to [AppUpdateChecker] on [prefs].
  final Future<AppUpdateInfo> Function(String lang)? cached;
  final Future<AppUpdateInfo> Function(String lang)? check;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  AppUpdateInfo _info = AppUpdateInfo.none;

  /// The version the user chose to skip (persisted).
  String? _skipped;

  /// The version closed with X for this run only.
  String? _closed;
  AppUpdateChecker? _checker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_run(first: true));
  }

  @override
  void didUpdateWidget(UpdateGate old) {
    super.didUpdateWidget(old);
    // Notes are per language: re-read them when the app language changes.
    if (old.lang != widget.lang) unawaited(_run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_run());
  }

  Future<void> _run({bool first = false}) async {
    final prefs = widget.prefs;
    final lang = widget.lang;
    if (widget.check == null && prefs == null) return;
    if (prefs != null) {
      _checker ??= AppUpdateChecker(prefs: prefs, brand: widget.brand);
      _skipped = await prefs.skipped();
    }
    // The cached answer first, so a forced update blocks at once even with no
    // connection; then the live one.
    if (first) _apply(await (widget.cached?.call(lang) ?? _checker!.cached(lang: lang)));
    _apply(await (widget.check?.call(lang) ?? _checker!.check(lang: lang)));
  }

  void _apply(AppUpdateInfo info) {
    if (!mounted) return;
    setState(() => _info = info);
  }

  void _close() => setState(() => _closed = _info.latest);

  Future<void> _skip() async {
    final latest = _info.latest;
    setState(() => _skipped = latest);
    await widget.prefs?.setSkipped(latest);
  }

  Future<void> _update() => launchUrl(Uri.parse(_info.url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final required = _info.status == UpdateStatus.required;
    final show =
        required || (_info.status == UpdateStatus.available && _skipped != _info.latest && _closed != _info.latest);
    if (!show) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned.fill(
        // The sheet is modal: nothing beneath it is reachable, by touch or by
        // a screen reader.
        child: BlockSemantics(
          child: Directionality(
            textDirection: widget.look.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Material(
              type: MaterialType.transparency,
              child: UpdateSheet(
                look: widget.look,
                info: _info,
                onUpdate: _update,
                onClose: required ? null : _close,
                onSkip: required ? null : _skip,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// `UpdateSheet` in the design's `update.jsx`: scrim, then a bottom sheet with
/// the mark, the headline, Current → New, what's new, and the action.
///
/// The design also plays a download bar and a "Restart now" step. A store
/// build cannot replace itself, so "Update now" hands over to the store and
/// those two phases are not ported.
class UpdateSheet extends StatefulWidget {
  const UpdateSheet({
    super.key,
    required this.look,
    required this.info,
    required this.onUpdate,
    this.onClose,
    this.onSkip,
  });
  final UpdateLook look;
  final AppUpdateInfo info;
  final VoidCallback onUpdate;

  /// Null for a required update — there is no way to dismiss it.
  final VoidCallback? onClose;
  final VoidCallback? onSkip;

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> with SingleTickerProviderStateMixin {
  /// `upSlideUp 0.3s cubic-bezier(0.16,1,0.3,1)`.
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
    ..forward();
  late final Animation<double> _curve = CurvedAnimation(parent: _in, curve: const Cubic(0.16, 1, 0.3, 1));

  /// The design's amber for "Required update" (`#8A6A10`).
  static const _requiredInk = Color(0xFF8A6A10);

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final u = look.copy;
    final ar = look.rtl;
    final info = widget.info;
    final required = info.status == UpdateStatus.required;
    final dismissable = widget.onClose != null;
    final title = required ? u.requiredTitle : u.availableTitle;
    final mq = MediaQuery.of(context);

    return Stack(children: [
      Positioned.fill(
        child: FadeTransition(
          opacity: _curve,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: const ColoredBox(color: Color(0x5C14202B)),
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 1.1), end: Offset.zero).animate(_curve),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.9, maxWidth: 560),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Padding(padding: EdgeInsets.only(bottom: 12), child: SheetGrab()),
                      // The close button rides above the mark, as in the
                      // design (`minHeight: 36`, then `marginTop: -12`).
                      Stack(children: [
                        Container(
                          // Full width, so the close button lands in the corner
                          // rather than at the edge of the centred text.
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            look.mark,
                            const SizedBox(height: 10),
                            Text(
                              (required ? u.eyebrowRequired : u.eyebrowNew).toUpperCase(),
                              textAlign: TextAlign.center,
                              style: Typo.meta(ar: ar).copyWith(
                                fontSize: FS.xs,
                                fontWeight: FontWeight.w700,
                                letterSpacing: ar ? 0 : 1.9,
                                color: required ? _requiredInk : look.accent.main,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(title, textAlign: TextAlign.center, style: Typo.heading(ar: ar)),
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                required ? u.requiredBody : u.availableBody,
                                textAlign: TextAlign.center,
                                style: Typo.bodySm(ar: ar).copyWith(color: T.fg2, height: 1.5),
                              ),
                            ),
                          ]),
                        ),
                        if (dismissable)
                          PositionedDirectional(
                            top: 0,
                            end: 0,
                            child: RoundBtn(
                              icon: LucideIcons.x,
                              semanticLabel: u.close,
                              ghost: true,
                              iconSize: 17,
                              onTap: widget.onClose,
                            ),
                          ),
                      ]),
                      Container(
                        margin: const EdgeInsets.only(top: 16, bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rLg)),
                        child: Row(children: [
                          Expanded(child: _version(u.current, info.installed, on: false)),
                          Icon(ar ? LucideIcons.arrowLeft : LucideIcons.arrowRight, size: 18, color: T.fg3),
                          Expanded(child: _version(u.newVersion, info.latest, on: true)),
                        ]),
                      ),
                    ]),
                  ),
                  if (info.notes.isNotEmpty)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          _Notes(look: look, notes: info.notes),
                          // The same notes as a web page, with whatever the
                          // sheet cannot show (images, tables). Opens in the
                          // browser, so it never stands between the user and
                          // the update when there is no connection.
                          if (info.notesUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PButton(
                                u.fullNotes,
                                icon: LucideIcons.externalLink,
                                variant: BtnVariant.ghost,
                                accent: look.accent,
                                ar: ar,
                                color: look.accent.main,
                                onTap: () => launchUrl(Uri.parse(info.notesUrl!), mode: LaunchMode.externalApplication),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))),
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + mq.padding.bottom),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      PButton(
                        u.updateNow,
                        icon: LucideIcons.download,
                        variant: BtnVariant.primary,
                        large: true,
                        block: true,
                        accent: look.accent,
                        ar: ar,
                        onTap: widget.onUpdate,
                      ),
                      if (widget.onSkip != null) ...[
                        const SizedBox(height: 6),
                        PButton(
                          u.skip,
                          variant: BtnVariant.ghost,
                          block: true,
                          ar: ar,
                          color: T.fg2,
                          onTap: widget.onSkip,
                        ),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _version(String label, String v, {required bool on}) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Typo.meta(ar: widget.look.rtl).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        // Version numbers read left to right in Arabic too.
        Text(
          v.isEmpty ? '—' : 'v$v',
          textDirection: TextDirection.ltr,
          style: Typo.num(size: FS.md, weight: FontWeight.w600, color: on ? widget.look.accent.main : T.fg2),
        ),
      ]);
}

/// "What's new": every release the user is behind, newest first. The newest
/// carries the design's eyebrow; older ones are headed by their version.
class _Notes extends StatelessWidget {
  const _Notes({required this.look, required this.notes});
  final UpdateLook look;
  final List<ReleaseNote> notes;

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ar = look.rtl;
    final accent = look.accent;
    final eyebrow = Typo.meta(ar: ar)
        .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, letterSpacing: ar ? 0 : 1.9, color: T.fg3);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      for (var n = 0; n < notes.length; n++) ...[
        if (n > 0) const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(
              child: n == 0
                  ? Text(look.copy.whatsNew.toUpperCase(), style: eyebrow)
                  : Text('v${notes[n].version}',
                      textDirection: TextDirection.ltr,
                      textAlign: ar ? TextAlign.right : TextAlign.left,
                      style: Typo.num(size: FS.xs, weight: FontWeight.w700, color: T.fg3)),
            ),
            if (notes[n].date != null)
              Text(_date(notes[n].date!), textDirection: TextDirection.ltr, style: Typo.meta(ar: ar)),
          ]),
        ),
        for (var i = 0; i < notes[n].items.length; i++) _item(notes[n].items[i], first: i == 0, ar: ar, accent: accent),
        if (notes[n].html != null && notes[n].html!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ReleaseNotesHtml(html: notes[n].html!, ar: ar, linkColor: accent.main),
          ),
      ],
      const SizedBox(height: 12),
    ]);
  }

  Widget _item(ReleaseNoteItem it, {required bool first, required bool ar, required Accent accent}) => Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
            child: Icon(releaseNoteIcon(it.icon), size: 17, color: accent.main),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(it.title, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              if (it.body.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ReleaseNotesHtml(html: it.body, ar: ar, linkColor: accent.main, small: true),
                ),
            ]),
          ),
        ]),
      );
}

/// Lucide glyph for a manifest icon name. A closed list — the manifest is
/// remote text, and an unknown name must still draw something sensible.
IconData releaseNoteIcon(String name) => switch (name) {
      'cloud-upload' => LucideIcons.cloudUpload,
      'cloud' => LucideIcons.cloud,
      'bell-ring' => LucideIcons.bellRing,
      'bell' => LucideIcons.bell,
      'map-pin' => LucideIcons.mapPin,
      'map' => LucideIcons.map,
      'wrench' => LucideIcons.wrench,
      'bug' => LucideIcons.bug,
      'shield-check' => LucideIcons.shieldCheck,
      'lock' => LucideIcons.lock,
      'zap' => LucideIcons.zap,
      'heart-pulse' => LucideIcons.heartPulse,
      'activity' => LucideIcons.activity,
      'pill' => LucideIcons.pill,
      'users' => LucideIcons.users,
      'qr-code' => LucideIcons.qrCode,
      'file-text' => LucideIcons.fileText,
      'folder' => LucideIcons.folder,
      'calendar' => LucideIcons.calendar,
      'languages' => LucideIcons.languages,
      'palette' => LucideIcons.palette,
      'search' => LucideIcons.search,
      'smartphone' => LucideIcons.smartphone,
      'refresh-cw' => LucideIcons.refreshCw,
      'star' => LucideIcons.star,
      _ => LucideIcons.sparkles,
    };
