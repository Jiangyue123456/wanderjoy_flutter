import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class WanderBottomNav extends StatelessWidget {
  const WanderBottomNav({
    required this.activeTab,
    required this.onChanged,
    super.key,
  });

  final AppTab activeTab;
  final ValueChanged<AppTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        tab: AppTab.explore,
        label: 'Explore',
        icon: Icons.explore_outlined,
      ),
      _NavItem(
        tab: AppTab.social,
        label: 'Social',
        icon: Icons.groups_2_outlined,
      ),
      _NavItem(
        tab: AppTab.memory,
        label: 'Memory',
        icon: Icons.auto_stories_outlined,
      ),
      _NavItem(tab: AppTab.me, label: 'Me', icon: Icons.person_outline),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final item in items)
              _NavButton(
                item: item,
                isActive: item.tab == activeTab,
                onTap: () => onChanged(item.tab),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : const Color(0xFFB2B2B2);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.tab, required this.label, required this.icon});

  final AppTab tab;
  final String label;
  final IconData icon;
}
