import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';
import 'family_screen.dart';

/// Home's Family card (Mother and Child.dc.html, board 01): tap 1 of the
/// two-tap path Home → Family → a member's emergency card. Shown on the
/// account holder's own Home, with up to three member avatars; with nobody
/// added yet it invites adding someone. Nothing shows until the list loads.
class FamilyHomeCard extends ConsumerWidget {
  const FamilyHomeCard({super.key, this.gutter = 16});

  /// Home's side gutter (16 on a phone, 24 from 600 wide).
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    // The people Family lists: dependents only (a prenatal profile lives
    // under the pregnancy, not in Family).
    final members =
        ref.watch(familyMembersProvider).valueOrNull?.where((m) => m.kind == ProfileKind.dependent).toList();
    if (members == null) return const SizedBox.shrink();
    final shown = members.take(3).toList();
    final extra = members.length - shown.length;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, 14),
      child: PCard(
        onTap: () => openFamily(context),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          const IconSquare(LucideIcons.users,
              bg: T.hueEmerald50, fg: T.hueEmeraldInk, size: 40, iconSize: 20, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              Text(
                members.isEmpty ? f.home_empty_sub(s.gender) : f.home_sub(members.length, s.gender),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.meta(ar: s.rtl),
              ),
            ]),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final (i, m) in shown.indexed)
                  Transform.translate(
                    offset: Offset((s.rtl ? 8.0 : -8.0) * i, 0),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.white, spreadRadius: 2)],
                      ),
                      child: MemberAvatar(m, size: 28),
                    ),
                  ),
                if (extra > 0)
                  Transform.translate(
                    offset: Offset((s.rtl ? 8.0 : -8.0) * shown.length, 0),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: T.ink50,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text('+$extra',
                          textDirection: TextDirection.ltr,
                          style: Typo.num(size: FS.xs, weight: FontWeight.w700).copyWith(color: T.fg2)),
                    ),
                  ),
              ]),
            ),
          ] else
            Icon(s.rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, size: 18, color: T.fg4),
        ]),
      ),
    );
  }
}
