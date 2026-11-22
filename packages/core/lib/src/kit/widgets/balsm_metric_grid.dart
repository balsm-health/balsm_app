import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

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
    required this.tiles,
    super.key,
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
        ? AppColors.danger
        : (tile.trend == BalsmMetricTrend.down ? AppColors.hueMintInk : AppColors.textTertiary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tile.icon != null) ...[
                Icon(tile.icon, size: 15, color: AppColors.textTertiary),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  tile.label,
                  style: const TextStyle(
                    fontSize: FontSizes.meta,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
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
                    fontSize: FontSizes.title,
                    color: AppColors.textPrimary,
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
                      fontSize: FontSizes.bodySm,
                      color: AppColors.textTertiary,
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
                  tile.trend == BalsmMetricTrend.up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: trendColor,
                ),
                const SizedBox(width: 6),
                Text(
                  tile.trendLabel!,
                  style: TextStyle(
                    fontSize: FontSizes.meta,
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
