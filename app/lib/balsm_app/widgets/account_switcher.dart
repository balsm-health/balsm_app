import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:core/core.dart';
import '../app_state.dart';
import 'family_qr_scan.dart';
import '../kit.dart';
import '../tokens.dart';

/// Account sheet (home.jsx AccountSwitcherSheet + AddFamilyMemberSheet).
///
/// P001 is still a single signed-in account. Extra members the patient adds
/// here are session-only name/relation rows — never fabricated sample PHI.
Future<void> showAccountSwitcher(BuildContext context) {
  final s = AppScope.of(context);
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (_) => _AccountSwitcherSheet(s),
  );
}

/// Nested picker opened from inside the add-member form — a plain white list,
/// rounded like every other sheet. The dialog presentation rounds all four
/// corners itself.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
        ),
        child: SafeArea(child: child),
      );
}

class _AccountSwitcherSheet extends ConsumerStatefulWidget {
  const _AccountSwitcherSheet(this.s);
  final PatientAppState s;
  @override
  ConsumerState<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<_AccountSwitcherSheet> {
  bool _adding = false;
  PatientAppState get s => widget.s;

  @override
  Widget build(BuildContext context) {
    if (_adding) {
      return _AddFamilyMemberSheet(
        s: s,
        selfName: (ref.read(accountSummaryProvider).valueOrNull?.displayName ?? '').trim(),
        onClose: () => setState(() => _adding = false),
        onAdd: (name, relation, dob, {linkJti}) {
          // Design: an unset relation falls back to "Family member" so the
          // switcher subtitle never starts with a dangling separator.
          final r = relation.trim().isEmpty ? s.strings.common.rel_default : relation.trim();
          // A scanned member starts as an outgoing link request (pending
          // until the other person approves in their own app); a manually
          // entered member is a local row and links immediately.
          s.addFamilyMember(
              name: name,
              relation: r,
              dob: dob,
              linkJti: linkJti,
              status: linkJti != null ? FamilyLinkStatus.pending : FamilyLinkStatus.linked);
          Navigator.pop(context);
        },
      );
    }

    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final displayName = (summary?.displayName ?? '').trim();
    final extras = s.extraFamily;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      padding: const EdgeInsets.only(bottom: 38),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(
                child: Text(s.strings.common.your_accounts,
                    style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(
                icon: LucideIcons.x,
                semanticLabel: s.strings.common.a11y_close,
                ghost: true,
                iconSize: 17,
                onTap: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        if (summary == null)
          _EmptyAccount(s)
        else
          _AccountRow(
            s,
            name: displayName,
            handle: summary.handle,
            color: T.hueAqua,
            active: s.activeFamilyId == null,
            onTap: () {
              s.selectFamilyMember(null);
              Navigator.pop(context);
            },
          ),
        for (final (i, member) in extras.indexed)
          if (member.isPending)
            _PendingRow(s, member: member, showDivider: i < extras.length)
          else
            _AccountRow(
              s,
              name: member.name,
              // Design: "{relation} · {age} yrs" — the age half is dropped when
              // no birth date was given.
              handle: switch (member.age) {
                final years? => '${member.relation} · $years ${s.strings.common.yrs}',
                _ => member.relation,
              },
              color: member.color,
              active: s.activeFamilyId == member.id,
              showDivider: i < extras.length,
              onTap: () {
                s.selectFamilyMember(member.id);
                Navigator.pop(context);
              },
            ),
        if (s.linkRequests.isNotEmpty) _LinkRequests(s),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: PButton(
            s.strings.settings.add_member,
            block: true,
            variant: BtnVariant.secondary,
            accent: s.accent,
            ar: s.rtl,
            icon: LucideIcons.userPlus,
            onTap: () => setState(() => _adding = true),
          ),
        ),
      ]),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow(
    this.s, {
    required this.name,
    required this.handle,
    required this.color,
    required this.active,
    required this.onTap,
    this.showDivider = false,
  });
  final PatientAppState s;
  final String name;
  final String? handle;
  final Color color;
  final bool active;
  final bool showDivider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final sub = (handle != null && handle!.isNotEmpty)
        ? (handle!.startsWith('@') || active ? (handle!.startsWith('@') ? handle! : '@$handle') : handle!)
        : s.strings.common.acc_active;
    return PressHighlight(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: showDivider ? const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink50))) : null,
        child: Row(children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.2), spreadRadius: 3)] : null,
            ),
            child: Avatar(initials: accountInitials(name), color: color, size: 48, ar: s.rtl),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (name.isNotEmpty)
                Text(name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              const SizedBox(height: 3),
              Text(sub,
                  textDirection: handle != null && handle!.startsWith('@') || (handle?.contains('@') ?? false)
                      ? TextDirection.ltr
                      : s.dir,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          if (active) Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
        ]),
      ),
    );
  }
}

class _EmptyAccount extends StatelessWidget {
  const _EmptyAccount(this.s);
  final PatientAppState s;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Row(children: [
          const Icon(LucideIcons.userCircle2, size: 22, color: T.fg3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.strings.common.acc_not_signed_in, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ),
        ]),
      );
}

/// Outgoing link request row: dimmed avatar, "Awaiting approval" badge, and a
/// Cancel action instead of the switch affordance.
class _PendingRow extends StatelessWidget {
  const _PendingRow(this.s, {required this.member, this.showDivider = false});
  final PatientAppState s;
  final FamilyMemberPreview member;
  final bool showDivider;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: showDivider ? const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink50))) : null,
      child: Row(children: [
        Opacity(
            opacity: 0.72,
            child: Avatar(initials: accountInitials(member.name), color: member.color, size: 48, ar: s.rtl)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFDF5DC), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.clock, size: 12, color: Color(0xFF9A6E00)),
                  const SizedBox(width: 5),
                  Text(s.strings.common.fam_pending,
                      style: Typo.bodySm(ar: s.rtl)
                          .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, color: const Color(0xFF9A6E00))),
                ]),
              ),
            ]),
          ]),
        ),
        PButton(s.strings.common.fam_cancel_request,
            variant: BtnVariant.ghost, ar: s.rtl, onTap: () => s.cancelPendingLink(member.id)),
      ]),
    );
  }
}

/// Incoming link requests — approve adds the requester as a linked member;
/// decline removes the request. Rendered only when the server has delivered
/// requests (never seeded locally).
class _LinkRequests extends StatelessWidget {
  const _LinkRequests(this.s);
  final PatientAppState s;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.strings.common.fam_link_requests.toUpperCase(),
            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, letterSpacing: s.rtl ? 0 : 1.6)),
        const SizedBox(height: 10),
        for (final r in List.of(s.linkRequests))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.accent.bg,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: T.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(initials: accountInitials(r.name), color: T.hueAqua, size: 42, ar: s.rtl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                    const SizedBox(height: 2),
                    Text([r.relation, if (r.when != null) r.when!].join(' \u00b7 '),
                        style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, fontSize: FS.xs)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: PButton(s.strings.common.fam_decline,
                      variant: BtnVariant.secondary, ar: s.rtl, onTap: () => s.declineLinkRequest(r.id)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PButton(s.strings.common.fam_approve,
                      variant: BtnVariant.primary,
                      accent: s.accent,
                      ar: s.rtl,
                      icon: LucideIcons.check,
                      onTap: () => s.approveLinkRequest(r.id)),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _AddFamilyMemberSheet extends StatefulWidget {
  const _AddFamilyMemberSheet({required this.s, required this.selfName, required this.onClose, required this.onAdd});
  final PatientAppState s;

  /// The signed-in account's display name — a manual entry matching it is
  /// rejected (you cannot add yourself as your own family member).
  final String selfName;
  final VoidCallback onClose;
  final void Function(String name, String relation, DateTime? dob, {String? linkJti}) onAdd;
  @override
  State<_AddFamilyMemberSheet> createState() => _AddFamilyMemberSheetState();
}

/// choose → scan → found | manual (design AddFamilyMemberSheet modes).
enum _AddMode { choose, scan, found, manual }

class _AddFamilyMemberSheetState extends State<_AddFamilyMemberSheet> {
  final _name = TextEditingController();
  String _relation = '';
  DateTime? _dob;

  _AddMode _mode = _AddMode.choose;
  ScannedProfile? _scanned;

  PatientAppState get s => widget.s;
  bool get canSave => _name.text.trim().length > 1;

  bool get _isSelfName {
    final self = widget.selfName;
    return self.isNotEmpty && _name.text.trim().toLowerCase() == self.toLowerCase();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<(String id, String label)> get _relations => [
        ('spouse', s.strings.common.rel_spouse),
        ('son', s.strings.common.rel_son),
        ('daughter', s.strings.common.rel_daughter),
        ('father', s.strings.common.rel_father),
        ('mother', s.strings.common.rel_mother),
        ('sibling', s.strings.common.rel_sibling),
        ('grandparent', s.strings.common.rel_grandparent),
        ('other', s.strings.common.rel_other),
      ];

  @override
  Widget build(BuildContext context) {
    final c = s.strings.common;
    final title = switch (_mode) {
      _AddMode.scan => c.fam_scan_title,
      _AddMode.found => c.fam_confirm_title,
      _ => s.strings.settings.add_member,
    };
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 32 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetGrab(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
          RoundBtn(
              icon: LucideIcons.x,
              semanticLabel: s.strings.common.a11y_close,
              ghost: true,
              iconSize: 17,
              onTap: widget.onClose),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1, color: T.ink100),
        const SizedBox(height: 16),
        ..._body(c),
      ]),
    );
  }

  List<Widget> _body(dynamic c) => switch (_mode) {
        _AddMode.choose => [
            _chooseCard(c.fam_scan_qr, c.fam_scan_qr_sub, LucideIcons.qrCode,
                accent: true, onTap: () => setState(() => _mode = _AddMode.scan)),
            const SizedBox(height: 10),
            _chooseCard(c.fam_manual, c.fam_manual_sub, LucideIcons.pencilLine,
                onTap: () => setState(() => _mode = _AddMode.manual)),
          ],
        _AddMode.scan => [
            FamilyQrScanView(
              onFound: (found) => setState(() {
                _scanned = found;
                _name.text = found.payload.name ?? '';
                _dob = DateTime.tryParse(found.payload.dateOfBirth ?? '');
                _mode = _AddMode.found;
              }),
              onManual: () => setState(() => _mode = _AddMode.manual),
            ),
          ],
        _AddMode.found => _foundBody(c),
        _ => _manualBody(c),
      };

  Widget _chooseCard(String title, String sub, IconData icon, {bool accent = false, required VoidCallback onTap}) {
    return PressHighlight(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.border)),
        child: Row(children: [
          IconSquare(icon,
              bg: accent ? s.accent.bg : T.ink50, fg: accent ? s.accent.main : T.fg2, size: 44, iconSize: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              const SizedBox(height: 2),
              Text(sub, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          Icon(s.rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, size: 18, color: T.fg3),
        ]),
      ),
    );
  }

  List<Widget> _foundBody(dynamic c) {
    final found = _scanned!;
    final name = _name.text.trim().isEmpty ? '—' : _name.text.trim();
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.hueMint50,
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: T.border),
        ),
        child: Row(children: [
          Avatar(initials: accountInitials(name), color: T.hueMint600, size: 48, ar: s.rtl),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
          ),
          const Icon(LucideIcons.badgeCheck, size: 22, color: T.hueMint600),
        ]),
      ),
      const SizedBox(height: 16),
      _labeled(c.relation, _relationField()),
      const SizedBox(height: 14),
      Text(c.fam_approval_note, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
      const SizedBox(height: 18),
      PButton(
        c.fam_send_request,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: () => widget.onAdd(_name.text.trim(), _relation, _dob, linkJti: found.jti),
      ),
      const SizedBox(height: 8),
      PButton(c.fam_scan_other,
          variant: BtnVariant.ghost, block: true, ar: s.rtl, onTap: () => setState(() => _mode = _AddMode.scan)),
    ];
  }

  List<Widget> _manualBody(dynamic c) {
    return [
      _labeled(
          c.member_name,
          TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
            decoration: _dec(s, c.member_name_ph),
          )),
      const SizedBox(height: 14),
      _labeled(
        c.relation,
        GestureDetector(
          onTap: () async {
            final picked = await showAppSheet<String>(
              context,
              textDirection: s.dir,
              builder: (ctx) => _PickerSheet(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final r in _relations)
                    ListTile(
                      title: Text(r.$2, style: Typo.body(ar: s.rtl)),
                      onTap: () => Navigator.pop(ctx, r.$2),
                    ),
                ]),
              ),
            );
            if (picked != null) setState(() => _relation = picked);
          },
          child: InputDecorator(
            decoration: _dec(s, null),
            child: Text(_relation.isEmpty ? c.select_relation : _relation,
                style: Typo.body(ar: s.rtl).copyWith(color: _relation.isEmpty ? T.fg4 : T.fg1)),
          ),
        ),
      ),
      const SizedBox(height: 14),
      // Optional — only used to show the member's age in the switcher.
      _labeled(
        c.member_dob,
        GestureDetector(
          onTap: _pickDob,
          child: InputDecorator(
            decoration: _dec(s, null),
            child: Row(children: [
              const Icon(LucideIcons.calendar, size: 17, color: T.fg3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _dob == null ? c.member_dob_ph : _formatDob(_dob!),
                  // Dates read left-to-right even in Arabic.
                  textDirection: TextDirection.ltr,
                  textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                  style: Typo.body(ar: s.rtl).copyWith(color: _dob == null ? T.fg4 : T.fg1),
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
            ]),
          ),
        ),
      ),
      if (_isSelfName) ...[
        const SizedBox(height: 10),
        Text(c.fam_self_add_manual, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.danger)),
      ],
      const SizedBox(height: 20),
      PButton(
        c.add_member_cta,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: canSave && !_isSelfName ? () => widget.onAdd(_name.text.trim(), _relation, _dob) : null,
      ),
      const SizedBox(height: 8),
      PButton(c.fam_scan_instead,
          variant: BtnVariant.ghost,
          block: true,
          ar: s.rtl,
          icon: LucideIcons.qrCode,
          onTap: () => setState(() => _mode = _AddMode.scan)),
    ];
  }

  /// `fmtDob` — day + localized month + year, always LTR.
  String _formatDob(DateTime d) {
    final months = s.strings.settings.cal_months.split('|');
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Uses the app's own calendar bottom-sheet, not the raw native dialog —
  /// the design switched every DOB field to this picker so they all match.
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showBalsmDatePicker(
      context,
      initial: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      title: s.strings.common.member_dob,
      confirmLabel: s.strings.onboarding.dob_confirm,
      months: s.strings.settings.cal_months.split('|'),
      weekdays: s.strings.settings.cal_weekdays.split('|'),
      rtl: s.rtl,
      accent: s.accent.main,
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  /// Relation picker field (shared by the found + manual modes).
  Widget _relationField() {
    final c = s.strings.common;
    return GestureDetector(
      onTap: () async {
        final picked = await showAppSheet<String>(
          context,
          textDirection: s.dir,
          builder: (ctx) => _PickerSheet(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final r in _relations)
                ListTile(
                  title: Text(r.$2, style: Typo.body(ar: s.rtl)),
                  onTap: () => Navigator.pop(ctx, r.$2),
                ),
            ]),
          ),
        );
        if (picked != null && mounted) setState(() => _relation = picked);
      },
      child: InputDecorator(
        decoration: _dec(s, null),
        child: Text(_relation.isEmpty ? c.select_relation : _relation,
            style: Typo.body(ar: s.rtl).copyWith(color: _relation.isEmpty ? T.fg4 : T.fg1)),
      ),
    );
  }

  Widget _labeled(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
        const SizedBox(height: 6),
        child,
      ]);

  InputDecoration _dec(PatientAppState s, String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.lg),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
      );
}
