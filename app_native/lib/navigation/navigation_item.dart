import 'package:flutter/material.dart';

class NavigationItem {
  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.tabIndex,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int tabIndex;
}
