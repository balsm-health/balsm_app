import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show accountSummaryProvider, showBalsmDatePicker;
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Account sheet (home.jsx AccountSwitcherSheet + AddFamilyMemberSheet).
///
/// P001 is still a single signed-in account. Extra members the patient adds
/// here are session-only name/relation rows — never fabricated sample PHI.
Future<void> showAccountSwitcher(BuildContext context) {
  final s = AppScope.of(context);
  return showModalBottomSheet(
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
          child: _AccountSwitcherSheet(s),
        ),
      ),
    ),
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
        onClose: () => setState(() => _adding = false),
        onAdd: (name, relation, dob) {
          // Design: an unset relation falls back to "Family member" so the
          // switcher subtitle never starts with a dangling separator.
          final r = relation.trim().isEmpty ? s.strings.common.rel_default : relation.trim();
          s.addFamilyMember(name: name, relation: r, dob: dob);
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
        Container(
            width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(
                child: Text(s.strings.common.your_accounts,
                    style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
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
            color: T.petalAqua,
            active: s.activeFamilyId == null,
            onTap: () {
              s.selectFamilyMember(null);
              Navigator.pop(context);
            },
          ),
        for (final (i, member) in extras.indexed)
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

class _AddFamilyMemberSheet extends StatefulWidget {
  const _AddFamilyMemberSheet({required this.s, required this.onClose, required this.onAdd});
  final PatientAppState s;
  final VoidCallback onClose;
  final void Function(String name, String relation, DateTime? dob) onAdd;
  @override
  State<_AddFamilyMemberSheet> createState() => _AddFamilyMemberSheetState();
}

class _AddFamilyMemberSheetState extends State<_AddFamilyMemberSheet> {
  final _name = TextEditingController();
  String _relation = '';
  DateTime? _dob;

  PatientAppState get s => widget.s;
  bool get canSave => _name.text.trim().length > 1;

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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 32 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: Text(s.strings.settings.add_member,
                  style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
          RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: widget.onClose),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1, color: T.ink100),
        const SizedBox(height: 16),
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
              final picked = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: Colors.white,
                builder: (ctx) => Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SafeArea(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final r in _relations)
                          ListTile(
                            title: Text(r.$2, style: Typo.body(ar: s.rtl)),
                            onTap: () => Navigator.pop(ctx, r.$2),
                          ),
                      ]),
                    ),
                  ),
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
        const SizedBox(height: 20),
        PButton(
          c.add_member_cta,
          large: true,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: canSave ? () => widget.onAdd(_name.text.trim(), _relation, _dob) : null,
        ),
      ]),
    );
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
