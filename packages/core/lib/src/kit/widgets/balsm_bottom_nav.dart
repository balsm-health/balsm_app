import 'package:flutter/material.dart';
import '../_tokens.dart';

/// Bottom nav tab definition.
class BalsmNavTab {
  const BalsmNavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom nav bar porting prototype `.tabbar`.
/// P001 5-slot order: [Home, Card, Meds, Sessions, Settings].
/// Active: icon weight emphasis + primary color + 3pt top indicator pill.
/// Frosted glass backdrop.
class BalsmBottomNav extends StatelessWidget {
  const BalsmBottomNav({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  /// Default P001 tabs.
  static const defaultTabs = [
    BalsmNavTab(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    BalsmNavTab(
      icon: Icons.credit_card_outlined,
      activeIcon: Icons.credit_card_rounded,
      label: 'Card',
    ),
    BalsmNavTab(
      icon: Icons.medication_outlined,
      activeIcon: Icons.medication_rounded,
      label: 'Meds',
    ),
    BalsmNavTab(
      icon: Icons.devices_outlined,
      activeIcon: Icons.devices_rounded,
      label: 'Sessions',
    ),
    BalsmNavTab(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  final List<BalsmNavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xEAFFFFFF), // 92% white
        border: Border(top: BorderSide(color: BalsmColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 10),
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final i = e.key;
            final tab = e.value;
            final isActive = i == currentIndex;
            return Expanded(
              child: _NavTab(
                tab: tab,
                isActive: isActive,
                onTap: () => onTap(i),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final BalsmNavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 3pt top indicator pill
            AnimatedContainer(
              duration: BalsmDuration.base,
              curve: kBalsmEaseOut,
              height: 3,
              width: isActive ? 20 : 0,
              decoration: BoxDecoration(
                color: BalsmColors.appAccent,
                borderRadius: BorderRadius.circular(BalsmRadius.pill),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              isActive ? tab.activeIcon : tab.icon,
              size: 22,
              color: isActive ? BalsmColors.appAccent : BalsmColors.fg4,
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? BalsmColors.appAccent : BalsmColors.fg4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
