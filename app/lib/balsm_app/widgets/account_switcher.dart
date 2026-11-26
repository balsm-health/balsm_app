import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import 'add_family_member_draft.dart';
import 'family_qr_scan.dart';

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
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
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
        selfName: (ref.read(accountSummaryProvider).value?.displayName ?? '').trim(),
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
            status: linkJti != null ? FamilyLinkStatus.pending : FamilyLinkStatus.linked,
          );
          Navigator.pop(context);
        },
      );
    }

    final summary = ref.watch(accountSummaryProvider).value;
    final displayName = (summary?.displayName ?? '').trim();
    final extras = s.extraFamily;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      padding: const EdgeInsets.only(bottom: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.strings.common.your_accounts,
                    style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: s.strings.common.a11y_close,
                  ghost: true,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.ink100),
          if (summary == null)
            _EmptyAccount(s)
          else
            _AccountRow(
              s,
              name: displayName,
              handle: summary.handle,
              color: AppColors.hueAqua,
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
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
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
        ],
      ),
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
        decoration:
            showDivider ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.ink50))) : null,
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.2), spreadRadius: 3)] : null,
              ),
              child: Avatar(initials: accountInitials(name), color: color, size: 48, ar: s.rtl),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    textDirection: handle != null && handle!.startsWith('@') || (handle?.contains('@') ?? false)
                        ? TextDirection.ltr
                        : s.dir,
                    style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            if (active) Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
          ],
        ),
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
        child: Row(
          children: [
            const Icon(LucideIcons.userCircle2, size: 22, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.strings.common.acc_not_signed_in,
                style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
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
      decoration: showDivider ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.ink50))) : null,
      child: Row(
        children: [
          Opacity(
            opacity: 0.72,
            child: Avatar(initials: accountInitials(member.name), color: member.color, size: 48, ar: s.rtl),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningBackground,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.clock, size: 12, color: AppColors.warningInk),
                          const SizedBox(width: 5),
                          Text(
                            s.strings.common.fam_pending,
                            style: Typo.bodySm(ar: s.rtl).copyWith(
                              fontSize: FontSizes.meta,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warningInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PButton(
            s.strings.common.fam_cancel_request,
            variant: BtnVariant.ghost,
            ar: s.rtl,
            onTap: () => s.cancelPendingLink(member.id),
          ),
        ],
      ),
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
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.strings.common.fam_link_requests.toUpperCase(),
            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, letterSpacing: s.rtl ? 0 : 1.6),
          ),
          const SizedBox(height: 10),
          for (final r in List.of(s.linkRequests))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: s.accent.bg,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(initials: accountInitials(r.name), color: AppColors.hueAqua, size: 42, ar: s.rtl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              style: Typo.body(ar: s.rtl)
                                  .copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [r.relation, if (r.when case final whenText?) whenText].join(' \u00b7 '),
                              style: Typo.bodySm(ar: s.rtl)
                                  .copyWith(color: AppColors.textTertiary, fontSize: FontSizes.meta),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PButton(
                          s.strings.common.fam_decline,
                          variant: BtnVariant.secondary,
                          ar: s.rtl,
                          onTap: () => s.declineLinkRequest(r.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PButton(
                          s.strings.common.fam_approve,
                          accent: s.accent,
                          ar: s.rtl,
                          icon: LucideIcons.check,
                          onTap: () => s.approveLinkRequest(r.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddFamilyMemberSheet extends ConsumerStatefulWidget {
  const _AddFamilyMemberSheet({required this.s, required this.selfName, required this.onClose, required this.onAdd});
  final PatientAppState s;

  /// The signed-in account's display name — a manual entry matching it is
  /// rejected (you cannot add yourself as your own family member).
  final String selfName;
  final VoidCallback onClose;
  final void Function(String name, String relation, DateTime? dob, {String? linkJti}) onAdd;
  @override
  ConsumerState<_AddFamilyMemberSheet> createState() => _AddFamilyMemberSheetState();
}

/// choose → scan → found | manual (design AddFamilyMemberSheet modes).
enum _AddMode { choose, scan, found, manual }

class _AddFamilyMemberSheetState extends ConsumerState<_AddFamilyMemberSheet> {
  final _name = TextEditingController();
  final Object _sheet = Object();
  _AddMode _mode = _AddMode.choose;

  PatientAppState get s => widget.s;

  @override
  void initState() {
    super.initState();
    // Only the manual and found bodies watch the draft, so without this it is
    // disposed whenever the sheet is in choose or scan mode and the typed name
    // or picked relation is lost on the way back.
    ref.listenManual(addFamilyMemberDraftProvider(_sheet), (_, __) {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _go(_AddMode mode) => setState(() => _mode = mode);

  void _onFound(ScannedProfile found) {
    ref.read(addFamilyMemberDraftProvider(_sheet).notifier).applyScan(found);
    _name.text = ref.read(addFamilyMemberDraftProvider(_sheet)).name;
    _go(_AddMode.found);
  }

  /// A scanned member is sent as a link request ([linked]); a manual one is
  /// a local row.
  void _add({required bool linked}) {
    final d = ref.read(addFamilyMemberDraftProvider(_sheet));
    widget.onAdd(d.name.trim(), d.relation, d.dob, linkJti: linked ? d.scanned?.jti : null);
  }

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
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(20, 10, 20, 32 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetGrab(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
              RoundBtn(
                icon: LucideIcons.x,
                semanticLabel: s.strings.common.a11y_close,
                ghost: true,
                iconSize: 17,
                onTap: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.ink100),
          const SizedBox(height: 16),
          switch (_mode) {
            _AddMode.choose => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChooseCard(
                    s: s,
                    title: c.fam_scan_qr(s.gender),
                    sub: c.fam_scan_qr_sub,
                    icon: LucideIcons.qrCode,
                    accent: true,
                    onTap: () => _go(_AddMode.scan),
                  ),
                  const SizedBox(height: 10),
                  _ChooseCard(
                    s: s,
                    title: c.fam_manual,
                    sub: c.fam_manual_sub,
                    icon: LucideIcons.pencilLine,
                    onTap: () => _go(_AddMode.manual),
                  ),
                ],
              ),
            _AddMode.scan => FamilyQrScanView(onFound: _onFound, onManual: () => _go(_AddMode.manual)),
            _AddMode.found => _FoundBody(
                s: s,
                sheet: _sheet,
                onSend: () => _add(linked: true),
                onScanOther: () => _go(_AddMode.scan),
              ),
            _AddMode.manual => _ManualBody(
                s: s,
                sheet: _sheet,
                selfName: widget.selfName,
                name: _name,
                onAdd: () => _add(linked: false),
                onScanInstead: () => _go(_AddMode.scan),
              ),
          },
        ],
      ),
    );
  }
}

/// One way to add a member: scan their QR, or type them in.
class _ChooseCard extends StatelessWidget {
  const _ChooseCard({
    required this.s,
    required this.title,
    required this.sub,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });
  final PatientAppState s;
  final String title;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => PressHighlight(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              IconSquare(
                icon,
                bg: accent ? s.accent.bg : AppColors.ink50,
                fg: accent ? s.accent.main : AppColors.textSecondary,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(sub, style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              Icon(forwardChevron(context), size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      );
}

/// A scanned profile: confirm who it is and the relation, then send the
/// link request.
class _FoundBody extends ConsumerWidget {
  const _FoundBody({required this.s, required this.sheet, required this.onSend, required this.onScanOther});
  final PatientAppState s;
  final Object sheet;
  final VoidCallback onSend;
  final VoidCallback onScanOther;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = s.strings.common;
    final typed = ref.watch(addFamilyMemberDraftProvider(sheet).select((d) => d.name.trim()));
    final name = typed.isEmpty ? '—' : typed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.hueMint50,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Avatar(initials: accountInitials(name), color: AppColors.hueMint600, size: 48, ar: s.rtl),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              const Icon(LucideIcons.badgeCheck, size: 22, color: AppColors.hueMint600),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Labeled(s: s, label: c.relation, child: _RelationField(s: s, sheet: sheet)),
        const SizedBox(height: 14),
        Text(c.fam_approval_note, style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 18),
        PButton(c.fam_send_request, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: onSend),
        const SizedBox(height: 8),
        PButton(c.fam_scan_other, variant: BtnVariant.ghost, block: true, ar: s.rtl, onTap: onScanOther),
      ],
    );
  }
}

/// Typed in by hand: name, relation and an optional date of birth.
class _ManualBody extends ConsumerWidget {
  const _ManualBody({
    required this.s,
    required this.sheet,
    required this.selfName,
    required this.name,
    required this.onAdd,
    required this.onScanInstead,
  });
  final PatientAppState s;
  final Object sheet;
  final String selfName;
  final TextEditingController name;
  final VoidCallback onAdd;
  final VoidCallback onScanInstead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = s.strings.common;
    final (canSave, isSelf) =
        ref.watch(addFamilyMemberDraftProvider(sheet).select((d) => (d.canSave, d.isSelf(selfName))));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Labeled(
          s: s,
          label: c.member_name,
          child: TextField(
            controller: name,
            autofocus: true,
            onChanged: (v) => ref.read(addFamilyMemberDraftProvider(sheet).notifier).setName(v),
            style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary, fontSize: FontSizes.subhead),
            decoration: _sheetInputDecoration(s, c.member_name_ph),
          ),
        ),
        const SizedBox(height: 14),
        _Labeled(s: s, label: c.relation, child: _RelationField(s: s, sheet: sheet)),
        const SizedBox(height: 14),
        // Optional — only used to show the member's age in the switcher.
        _Labeled(s: s, label: c.member_dob, child: _DobField(s: s, sheet: sheet)),
        if (isSelf) ...[
          const SizedBox(height: 10),
          Text(c.fam_self_add_manual, style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.danger)),
        ],
        const SizedBox(height: 20),
        PButton(
          c.add_member_cta,
          large: true,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: canSave && !isSelf ? onAdd : null,
        ),
        const SizedBox(height: 8),
        PButton(
          c.fam_scan_instead,
          variant: BtnVariant.ghost,
          block: true,
          ar: s.rtl,
          icon: LucideIcons.qrCode,
          onTap: onScanInstead,
        ),
      ],
    );
  }
}

/// Relation picker field (shared by the found + manual modes).
class _RelationField extends ConsumerWidget {
  const _RelationField({required this.s, required this.sheet});
  final PatientAppState s;
  final Object sheet;

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

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await showAppSheet<String>(
      context,
      textDirection: s.dir,
      builder: (ctx) => _PickerSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _relations
              .map(
                (r) => ListTile(
                  title: Text(r.$2, style: Typo.body(ar: s.rtl)),
                  onTap: () => Navigator.pop(ctx, r.$2),
                ),
              )
              .toList(),
        ),
      ),
    );
    // The sheet may have closed while the picker was open.
    if (picked != null && context.mounted) {
      ref.read(addFamilyMemberDraftProvider(sheet).notifier).setRelation(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = s.strings.common;
    final relation = ref.watch(addFamilyMemberDraftProvider(sheet).select((d) => d.relation));
    return GestureDetector(
      onTap: () => _pick(context, ref),
      child: InputDecorator(
        decoration: _sheetInputDecoration(s, null),
        child: Text(
          relation.isEmpty ? c.select_relation(s.gender) : relation,
          style: Typo.body(ar: s.rtl).copyWith(color: relation.isEmpty ? AppColors.textHint : AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// The optional date of birth, from the app's own calendar sheet (not the
/// raw native dialog — the design switched every DOB field to this picker
/// so they all match).
class _DobField extends ConsumerWidget {
  const _DobField({required this.s, required this.sheet});
  final PatientAppState s;
  final Object sheet;

  /// `fmtDob` — day + localized month + year, always LTR.
  String _format(DateTime d) {
    final months = s.strings.settings.cal_months.split('|');
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, DateTime? dob) async {
    final now = DateTime.now();
    final picked = await showBalsmDatePicker(
      context,
      initial: dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      title: s.strings.common.member_dob,
      confirmLabel: s.strings.onboarding.dob_confirm,
      months: s.strings.settings.cal_months.split('|'),
      weekdays: s.strings.settings.cal_weekdays.split('|'),
      rtl: s.rtl,
      accent: s.accent.main,
    );
    if (picked != null && context.mounted) ref.read(addFamilyMemberDraftProvider(sheet).notifier).setDob(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dob = ref.watch(addFamilyMemberDraftProvider(sheet).select((d) => d.dob));
    return GestureDetector(
      onTap: () => _pick(context, ref, dob),
      child: InputDecorator(
        decoration: _sheetInputDecoration(s, null),
        child: Row(
          children: [
            const Icon(LucideIcons.calendar, size: 17, color: AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                switch (dob) {
                  final dob? => _format(dob),
                  _ => s.strings.common.member_dob_ph,
                },
                // Dates read left-to-right even in Arabic.
                textDirection: TextDirection.ltr,
                textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                style: Typo.body(ar: s.rtl).copyWith(color: dob == null ? AppColors.textHint : AppColors.textPrimary),
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 15, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A form field with its label above.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.s, required this.label, required this.child});
  final PatientAppState s;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          child,
        ],
      );
}

InputDecoration _sheetInputDecoration(PatientAppState s, String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint, fontSize: FontSizes.subhead),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: s.accent.main, width: 1.5),
      ),
    );
