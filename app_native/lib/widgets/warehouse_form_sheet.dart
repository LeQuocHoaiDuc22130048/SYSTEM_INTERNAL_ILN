import 'package:flutter/material.dart';

/// Keeps the form footer above the keyboard while its fields scroll.
class WarehouseFormSheet extends StatelessWidget {
  const WarehouseFormSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: (media.size.height * 0.9 - media.viewInsets.bottom).clamp(
            0.0,
            constraints.maxHeight,
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}
