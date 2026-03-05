import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/is_tablet.dart';

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;

  const CustomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final double width = ScreenSize.screenWidth(context);
    final bool isTablet = ScreenSize.isTablet(context);
    final double sideMargin = isTablet ? (width - 450) / 2 : 0;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;
    final Color activeItemColor = isDark
        ? CupertinoColors.black
        : CupertinoColors.white;
    final Color inactiveItemIconColor = CupertinoColors.systemGrey2;
    final Color activeItemTextColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: sideMargin > 0 ? sideMargin : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(0, CupertinoIcons.home, "Home", activeItemColor, activeItemTextColor, inactiveItemIconColor),
          _buildNavItem(1, CupertinoIcons.search, "Search", activeItemColor, activeItemTextColor, inactiveItemIconColor),
          _buildNavItem(2, CupertinoIcons.calendar_today, "Plan", activeItemColor, activeItemTextColor, inactiveItemIconColor),
          _buildNavItem(3, CupertinoIcons.person_circle, "Profile", activeItemColor, activeItemTextColor, inactiveItemIconColor),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index,
      IconData icon,
      String label,
      Color activeBgColor,
      Color activeTextColor,
      Color inactiveIconColor,
      ) {
    bool isSelected = selectedIndex == index;

    return GestureDetector(
      key: Key('nav_$label'),
      onTap: () => onTabChange(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeTextColor : inactiveIconColor,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}