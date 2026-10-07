import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/app_banner.dart';
import '../models/banner_canvas_design.dart';

class BannerCanvas extends StatelessWidget {
  final AppBanner banner;
  final BannerCanvasDesign design;
  final String baseUrl;
  final Widget mascot;
  final VoidCallback onTap;
  final void Function(AppBannerButton) onButtonTap;
  final TextStyle Function(String, TextStyle) textStyle;

  const BannerCanvas({
    super.key,
    required this.banner,
    required this.design,
    required this.baseUrl,
    required this.mascot,
    required this.onTap,
    required this.onButtonTap,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final background = banner.backgroundImageUrl;
    return Align(
      child: AspectRatio(
        aspectRatio: 2,
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: banner.gradientColorList,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: background == null || background.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(
                          background.startsWith('http')
                              ? background
                              : '$baseUrl$background',
                        ),
                        fit: BoxFit.cover,
                        colorFilter: banner.darkenOverlay
                            ? const ColorFilter.mode(
                                Color(0x59000000),
                                BlendMode.darken,
                              )
                            : null,
                      ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = constraints.maxWidth / 360;
                  return Stack(
                    children: [
                      for (final entry in design.nodes.entries)
                        if (_visible(entry.key))
                          Positioned(
                            key: ValueKey('canvas-${entry.key}'),
                            left: entry.value.x / 100 * constraints.maxWidth,
                            top: entry.value.y / 100 * constraints.maxHeight,
                            width:
                                entry.value.width / 100 * constraints.maxWidth,
                            height:
                                entry.value.height /
                                100 *
                                constraints.maxHeight,
                            child: ClipRect(
                              child: _element(entry.key, entry.value, scale),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _visible(String id) {
    if (id == 'mascot') {
      return !['NONE', 'EMPTY'].contains(banner.imagePosition);
    }
    if (id.startsWith('button')) {
      return int.parse(id.substring(6)) < banner.buttons.length;
    }
    return _text(id).isNotEmpty;
  }

  String _text(String id) => switch (id) {
    'badge' => banner.badgeText ?? '',
    'title' => banner.title,
    'subtitle' => banner.subtitle ?? '',
    _ => '',
  };

  Widget _element(String id, BannerCanvasNode node, double scale) {
    if (id == 'mascot') {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          node.style['flip'] == true ? -1 : 1,
          1,
          1,
        ),
        child: mascot,
      );
    }
    final color = BannerCanvasNode.color(node.style['color']) ?? Colors.white;
    final style = textStyle(
      (node.style['fontFamily']?.toString().trim().isNotEmpty ?? false)
          ? node.style['fontFamily'].toString()
          : banner.fontFamily,
      TextStyle(
        fontSize: node.number('fontSize', 12, 8, 48) * scale,
        fontWeight:
            FontWeight.values[(node.number('fontWeight', 400, 100, 900) / 100)
                    .round() -
                1],
        color: color,
        height: 1.2,
      ),
    );
    final align = switch (node.style['align']) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    final gradient = node.style['gradient'] is String
        ? (node.style['gradient'] as String)
              .split(',')
              .map((value) => BannerCanvasNode.color(value.trim()))
              .whereType<Color>()
              .toList()
        : <Color>[];
    final decoration = BoxDecoration(
      color: gradient.length > 1
          ? null
          : BannerCanvasNode.color(node.style['background']),
      gradient: gradient.length > 1
          ? LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      borderRadius: BorderRadius.circular(
        node.number('radius', 0, 0, 50) * scale,
      ),
      border: id.startsWith('button') ? Border.all(color: color) : null,
    );
    if (id.startsWith('button')) {
      final button = banner.buttons[int.parse(id.substring(6))];
      final icon = switch (node.style['icon']) {
        'phone' => Icons.phone_outlined,
        'arrow' => Icons.arrow_forward,
        'cart' => Icons.shopping_cart_outlined,
        'external' => Icons.open_in_new,
        _ => null,
      };
      return GestureDetector(
        onTap: () => onButtonTap(button),
        child: Container(
          decoration: decoration,
          padding: EdgeInsets.all(3 * scale),
          child: LayoutBuilder(
            builder: (_, constraints) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    button.text,
                    style: style,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.clip,
                  ),
                ),
                if (icon != null) ...[
                  SizedBox(
                    width: math.min(4 * scale, constraints.maxWidth / 20),
                  ),
                  Icon(
                    icon,
                    size: math.min(
                      style.fontSize ?? 12,
                      math.min(constraints.maxWidth / 4, constraints.maxHeight),
                    ),
                    color: color,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    final verticalAlignment = switch (node.style['verticalAlign']) {
      'center' => Alignment.center,
      'bottom' => Alignment.bottomCenter,
      _ => Alignment.topCenter,
    };
    final lines = _text(id).split('\n');
    final lineColors = node.style['lineColors'];
    return Container(
      decoration: decoration,
      alignment: verticalAlignment,
      child: SizedBox(
        width: double.infinity,
        child: RichText(
          textAlign: align,
          overflow: TextOverflow.clip,
          textScaler: TextScaler.noScaling,
          text: TextSpan(
            style: style,
            children: [
              for (var index = 0; index < lines.length; index++)
                TextSpan(
                  text: '${index == 0 ? '' : '\n'}${lines[index]}',
                  style: TextStyle(
                    color: lineColors is List && index < lineColors.length
                        ? BannerCanvasNode.color(lineColors[index]) ?? color
                        : color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
