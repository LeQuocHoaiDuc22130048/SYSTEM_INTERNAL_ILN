import 'dart:convert';
import 'package:flutter/material.dart';

class AppBannerButton {
  final String text;
  final String actionType; // BOOKING, REPAIR_ORDER, LINK, SCREEN, CALL, NONE
  final String? actionValue;
  final String styleType; // PRIMARY, SECONDARY, OUTLINE

  const AppBannerButton({
    required this.text,
    this.actionType = 'BOOKING',
    this.actionValue,
    this.styleType = 'PRIMARY',
  });

  factory AppBannerButton.fromJson(Map<String, dynamic> json) {
    return AppBannerButton(
      text: json['text']?.toString() ?? 'Bấm vào đây',
      actionType: json['actionType']?.toString() ?? 'BOOKING',
      actionValue: json['actionValue']?.toString(),
      styleType: json['styleType']?.toString() ?? 'PRIMARY',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'actionType': actionType,
      'actionValue': actionValue,
      'styleType': styleType,
    };
  }
}

class AppBanner {
  final String id;
  final String title;
  final String? badgeText;
  final String? subtitle;
  final String? buttonText;
  final String actionType; // BOOKING, REPAIR_ORDER, LINK, SCREEN, CALL, NONE
  final String? actionValue;
  final String buttonPosition; // BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT, TOP_RIGHT
  final List<AppBannerButton> buttons;
  final String? imageUrl;
  final String? backgroundImageUrl;
  final String gradientColors;
  final int displayOrder;
  final bool isActive;

  const AppBanner({
    required this.id,
    required this.title,
    this.badgeText,
    this.subtitle,
    this.buttonText,
    this.actionType = 'BOOKING',
    this.actionValue,
    this.buttonPosition = 'BOTTOM_LEFT',
    this.buttons = const [],
    this.imageUrl,
    this.backgroundImageUrl,
    this.gradientColors = '#2563EB,#4F46E5,#1D4ED8',
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    final rawBtnText = json['buttonText']?.toString() ?? 'Đặt lịch ngay';
    final rawActionType = json['actionType']?.toString() ?? 'BOOKING';
    final rawActionValue = json['actionValue']?.toString();

    final parsedButtons = <AppBannerButton>[];
    if (json['buttons'] is List) {
      for (final item in (json['buttons'] as List)) {
        if (item is Map<String, dynamic>) {
          parsedButtons.add(AppBannerButton.fromJson(item));
        } else if (item is Map) {
          parsedButtons.add(AppBannerButton.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } else if (json['buttonsJson'] is String && json['buttonsJson'].toString().trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(json['buttonsJson']);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              parsedButtons.add(AppBannerButton.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      } catch (_) {}
    }

    if (parsedButtons.isEmpty) {
      parsedButtons.add(AppBannerButton(
        text: rawBtnText,
        actionType: rawActionType,
        actionValue: rawActionValue,
        styleType: 'PRIMARY',
      ));
    }

    return AppBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      badgeText: json['badgeText']?.toString(),
      subtitle: json['subtitle']?.toString(),
      buttonText: rawBtnText,
      actionType: rawActionType,
      actionValue: rawActionValue,
      buttonPosition: json['buttonPosition']?.toString() ?? 'BOTTOM_LEFT',
      buttons: parsedButtons,
      imageUrl: json['imageUrl']?.toString(),
      backgroundImageUrl: json['backgroundImageUrl']?.toString(),
      gradientColors:
          json['gradientColors']?.toString() ?? '#2563EB,#4F46E5,#1D4ED8',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'badgeText': badgeText,
      'subtitle': subtitle,
      'buttonText': buttonText,
      'actionType': actionType,
      'actionValue': actionValue,
      'buttonPosition': buttonPosition,
      'buttons': buttons.map((b) => b.toJson()).toList(),
      'imageUrl': imageUrl,
      'backgroundImageUrl': backgroundImageUrl,
      'gradientColors': gradientColors,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }

  /// Parses comma-separated hex colors (e.g. "#2563EB,#4F46E5,#1D4ED8") into Flutter Colors.
  List<Color> get gradientColorList {
    try {
      final parts = gradientColors.split(',');
      final colors = <Color>[];
      for (final part in parts) {
        final clean = part.trim().replaceFirst('#', '');
        if (clean.length == 6) {
          colors.add(Color(int.parse('0xFF$clean')));
        } else if (clean.length == 8) {
          colors.add(Color(int.parse('0x$clean')));
        }
      }
      if (colors.isNotEmpty) {
        if (colors.length == 1) {
          return [colors.first, colors.first];
        }
        return colors;
      }
    } catch (_) {}
    return const [
      Color(0xFF2563EB),
      Color(0xFF4F46E5),
      Color(0xFF1D4ED8),
    ];
  }

  static const AppBanner defaultBanner = AppBanner(
    id: 'default',
    title: 'Bảo Trì & Sửa Chữa Inverter',
    badgeText: '⚡ ƯU ĐÃI ĐẶC BIỆT',
    subtitle: 'Giảm ngay 25% GIÁ TRỊ cho lượt đặt dịch vụ đầu tiên!',
    buttonText: 'Đặt lịch ngay',
    actionType: 'BOOKING',
    actionValue: 'Gói bảo trì ưu đãi 25%',
    buttonPosition: 'BOTTOM_LEFT',
    buttons: [
      AppBannerButton(
        text: 'Đặt lịch ngay',
        actionType: 'BOOKING',
        actionValue: 'Gói bảo trì ưu đãi 25%',
        styleType: 'PRIMARY',
      ),
    ],
    gradientColors: '#2563EB,#4F46E5,#1D4ED8',
    displayOrder: 1,
    isActive: true,
  );
}
