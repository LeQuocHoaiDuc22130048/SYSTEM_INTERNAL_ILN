import 'dart:convert';
import 'package:flutter/material.dart';

class BannerCanvasDesign {
  final Map<String, BannerCanvasNode> nodes;
  const BannerCanvasDesign(this.nodes);

  static Map<String, BannerCanvasNode> _defaults() {
    final values = <String, Map<String, dynamic>>{
      'badge': {
        'x': 5,
        'y': 8,
        'width': 58,
        'height': 16,
        'fontSize': 10,
        'fontWeight': 700,
        'color': '#ffffff',
        'background': '#ffffff33',
        'radius': 16,
      },
      'title': {
        'x': 5,
        'y': 28,
        'width': 62,
        'height': 23,
        'fontSize': 18,
        'fontWeight': 800,
        'color': '#ffffff',
      },
      'subtitle': {
        'x': 5,
        'y': 53,
        'width': 62,
        'height': 26,
        'fontSize': 11,
        'fontWeight': 400,
        'color': '#ffffff',
      },
      'mascot': {'x': 68, 'y': 12, 'width': 30, 'height': 86, 'flip': false},
      'button0': {
        'x': 5,
        'y': 80,
        'width': 31,
        'height': 16,
        'fontSize': 11,
        'fontWeight': 700,
        'color': '#2563eb',
        'background': '#ffffff',
        'radius': 20,
        'icon': 'arrow',
      },
      'button1': {
        'x': 38,
        'y': 80,
        'width': 28,
        'height': 16,
        'fontSize': 11,
        'fontWeight': 700,
        'color': '#ffffff',
        'background': '#2563eb',
        'radius': 8,
        'icon': 'phone',
      },
      'button2': {
        'x': 68,
        'y': 80,
        'width': 28,
        'height': 16,
        'fontSize': 11,
        'fontWeight': 700,
        'color': '#ffffff',
        'background': '#2563eb',
        'radius': 8,
        'icon': 'arrow',
      },
    };
    return values.map(
      (id, data) => MapEntry(id, BannerCanvasNode.parse(data)!),
    );
  }

  static BannerCanvasDesign? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['version'] != 1 || data['nodes'] is! Map) {
        return null;
      }
      final nodes = <String, BannerCanvasNode>{};
      for (final entry in (data['nodes'] as Map).entries) {
        final id = entry.key.toString();
        if (!RegExp(
              r'^(badge|title|subtitle|mascot|button[0-2])$',
            ).hasMatch(id) ||
            entry.value is! Map) {
          continue;
        }
        final node = BannerCanvasNode.parse(
          Map<String, dynamic>.from(entry.value),
        );
        if (node != null) {
          nodes[id] = BannerCanvasNode(
            node.x,
            node.y,
            node.width,
            node.height,
            {..._defaults()[id]!.style, ...node.style},
          );
        }
      }
      return nodes.isEmpty
          ? null
          : BannerCanvasDesign({..._defaults(), ...nodes});
    } catch (_) {
      return null;
    }
  }
}

class BannerCanvasNode {
  final double x, y, width, height;
  final Map<String, dynamic> style;
  const BannerCanvasNode(this.x, this.y, this.width, this.height, this.style);

  static BannerCanvasNode? parse(Map<String, dynamic> data) {
    for (final field in ['x', 'y', 'width', 'height']) {
      if (data[field] is! num || !(data[field] as num).toDouble().isFinite) {
        return null;
      }
    }
    final width = (data['width'] as num).toDouble().clamp(5.0, 100.0);
    final height = (data['height'] as num).toDouble().clamp(5.0, 100.0);
    return BannerCanvasNode(
      (data['x'] as num).toDouble().clamp(0.0, 100 - width),
      (data['y'] as num).toDouble().clamp(0.0, 100 - height),
      width,
      height,
      data,
    );
  }

  double number(String key, double fallback, double min, double max) {
    final value = style[key];
    return value is num && value.toDouble().isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  static Color? color(Object? raw) {
    if (raw == 'transparent') return Colors.transparent;
    if (raw is! String ||
        !RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(raw)) {
      return null;
    }
    final value = int.parse(raw.substring(1), radix: 16);
    return Color(
      raw.length == 9
          ? ((value & 255) << 24) | (value >> 8)
          : 0xff000000 | value,
    );
  }
}
