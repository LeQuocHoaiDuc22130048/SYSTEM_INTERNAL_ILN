import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class BadgeIconButton extends StatelessWidget {
  const BadgeIconButton({
    super.key,
    required this.icon,
    required this.badge,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String badge;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final showBadge = badge != '0';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, size: 21),
          onPressed: onPressed,
          tooltip: tooltip,
        ),
        if (showBadge)
          Positioned(
            right: 10,
            top: 10,
            child: BadgePill(text: badge, size: 16),
          ),
      ],
    );
  }
}

class BadgePill extends StatelessWidget {
  const BadgePill({super.key, required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: size <= 14 ? 8 : 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
