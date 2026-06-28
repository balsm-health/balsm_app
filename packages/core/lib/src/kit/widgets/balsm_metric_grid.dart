import 'package:flutter/material.dart';
import '../_tokens.dart';

enum BalsmMetricTrend { up, down, none }

/// A single metric tile used inside `BalsmMetricGrid`.
class BalsmMetricTile {
  const BalsmMetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.trend = BalsmMetricTrend.none,
    this.trendLabel,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final BalsmMetricTrend trend;
  final String? trendLabel;
}

/// 2×2 metric grid porting prototype `.metric-grid`.
/// P001 use: home today-summary (next dose, taken count, missed count).
class BalsmMetricGrid extends StatelessWidget {
  const BalsmMetricGrid({
    super.key,
    required this.tiles,
  });

  final List<BalsmMetricTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: tiles.map(_MetricTile.new).toList(),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.tile);
  final BalsmMetricTile tile;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final trendColor = tile.trend == BalsmMetricTrend.up
        ? BalsmColors.danger
        : (tile.trend == BalsmMetricTrend.down
            ? const Color(0xFF1F6A36)
            : BalsmColors.fg3);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        border: Border.all(color: BalsmColors.border),
        boxShadow: BalsmShadow.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tile.icon != null) ...[
                Icon(tile.icon, size: 15, color: BalsmColors.fg3),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  tile.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BalsmColors.fg3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: tile.value,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: BalsmColors.fg1,
                    letterSpacing: -0.01 * 26,
                    height: 1.1,
                  ),
                ),
                if (tile.unit != null)
                  TextSpan(
                    text: isRtl ? ' ${tile.unit}' : ' ${tile.unit}',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: BalsmColors.fg3,
                    ),
                  ),
              ],
            ),
          ),
          if (tile.trend != BalsmMetricTrend.none && tile.trendLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  tile.trend == BalsmMetricTrend.up
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                  color: trendColor,
                ),
                const SizedBox(width: 6),
                Text(
                  tile.trendLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
