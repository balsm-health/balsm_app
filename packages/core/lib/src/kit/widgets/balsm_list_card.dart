import 'package:flutter/material.dart';
import '../_tokens.dart';
import 'balsm_list_row.dart';

export 'balsm_list_row.dart';

/// Card wrapping vertically-stacked `BalsmListRow` items with shared padding.
/// Porting prototype `.list-card` (overflow hidden, 0 20px 16px margin).
class BalsmListCard extends StatelessWidget {
  const BalsmListCard({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final List<BalsmListRow> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    // Remove divider on last row
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final row = children[i];
      rows.add(BalsmListRow(
        key: row.key,
        leading: row.leading,
        label: row.label,
        sublabel: row.sublabel,
        trailing: row.trailing,
        onTap: row.onTap,
        showChevron: row.showChevron,
        showDivider: i < children.length - 1,
      ));
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: BalsmColors.surface,
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        border: Border.all(color: BalsmColors.border),
        boxShadow: BalsmShadow.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}
