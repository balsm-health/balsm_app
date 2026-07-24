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
    final rows = children.indexed
        .map<Widget>((e) => BalsmListRow(
              key: e.$2.key,
              leading: e.$2.leading,
              label: e.$2.label,
              sublabel: e.$2.sublabel,
              trailing: e.$2.trailing,
              onTap: e.$2.onTap,
              showChevron: e.$2.showChevron,
              showDivider: e.$1 < children.length - 1,
            ))
        .toList();

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
