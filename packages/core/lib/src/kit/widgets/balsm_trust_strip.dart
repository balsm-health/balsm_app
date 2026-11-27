import 'package:material_ui/material_ui.dart';

import '../../localization/core_messages.dart';
import '../tokens.dart';

/// Trust item data for `BalsmTrustStrip`.
class BalsmTrustItem {
  const BalsmTrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Trust strip porting prototype `.trust` (3 evenly-spaced icons + labels).
/// P001: shield-check (on-device) + user-check (private) + wifi-off (offline-ready).
class BalsmTrustStrip extends StatelessWidget {
  const BalsmTrustStrip({
    required this.items,
    super.key,
  });

  /// Default P001 trust strip items, in the language of [context].
  static List<BalsmTrustItem> defaultItems(BuildContext context) {
    final m = coreMessagesOf(context);
    return [
      BalsmTrustItem(icon: Icons.shield_rounded, label: m.trust_on_device),
      BalsmTrustItem(icon: Icons.person_pin_rounded, label: m.trust_private),
      BalsmTrustItem(icon: Icons.wifi_off_rounded, label: m.trust_offline),
    ];
  }

  final List<BalsmTrustItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items.map((item) => Expanded(child: _TrustItem(item: item))).toList(),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.item});
  final BalsmTrustItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 22, color: AppColors.hueBlue),
        const SizedBox(height: 6),
        Text(
          item.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: FontSizes.eyebrow,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
