import 'package:flutter/material.dart';

class AppColors {
  // CRM Motion Design System Brand Palette
  static const Color brandNavy = Color(0xFF263F63);
  static const Color brandBlue = Color(0xFF4778B8);
  static const Color brandCyan = Color(0xFF55C7E8);

  // Primary colors
  static const Color primary = Color(0xFF2563EB); // blue-600
  static const Color primaryDark = brandNavy;
  static const Color primaryLight = brandBlue;

  // Background colors
  static const Color backgroundLight = Color(0xFFF4F7FB);
  static const Color backgroundDark = Color(0xFF0B1320);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E293B); // slate-800
  static const Color surfaceSubtleLight = Color(0xFFF8FAFC);
  static const Color surfaceSubtleDark = Color(0xFF162338);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF0F172A); // slate-900
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // slate-50
  static const Color textSecondaryLight = Color(0xFF64748B); // slate-500
  static const Color textSecondaryDark = Color(0xFF94A3B8); // slate-400
  static const Color textTertiaryLight = Color(0xFF94A3B8); // slate-400
  static const Color textTertiaryDark = Color(0xFF64748B); // slate-500

  // Border colors
  static const Color borderLight = Color(0xFFE2E8F0); // slate-200
  static const Color borderDark = Color(0xFF334155); // slate-700

  // Status colors
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color successLight = Color(0xFFD1FAE5); // emerald-100
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color warningLight = Color(0xFFFEF3C7); // amber-100
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color errorLight = Color(0xFFFEE2E2); // red-100
  static const Color info = brandBlue;
  static const Color infoLight = Color(0xFFE8EFF8);

  // Gradient colors for login
  static const Color gradientStart = Color(0xFF0A1628);
  static const Color gradientMiddle = brandNavy;
  static const Color gradientEnd = Color(0xFF0A1F3C);

  // Accent colors
  static const Color purple = Color(0xFF9333EA); // purple-600
  static const Color purpleLight = Color(0xFFF3E8FF); // purple-100
  static const Color emerald = Color(0xFF10B981); // emerald-500
  static const Color emeraldLight = Color(0xFFD1FAE5); // emerald-100
  static const Color amber = Color(0xFFF59E0B); // amber-500
  static const Color amberLight = Color(0xFFFEF3C7); // amber-100
  static const Color red = Color(0xFFEF4444); // red-500
  static const Color redLight = Color(0xFFFEE2E2); // red-100

  // Sidebar
  static const Color sidebarBg = Color(0xFF182944);
  static const Color sidebarActive = brandBlue;
  static const Color sidebarHover = Color(0x1AFFFFFF); // white/10

  // Chart colors
  static const Color chartPending = Color(0xFFF59E0B); // amber-500
  static const Color chartInProgress = brandBlue;
  static const Color chartCompleted = Color(0xFF10B981); // emerald-500
  static const Color chartDelivered = Color(0xFF64748B); // slate-500
}
