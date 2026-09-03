import 'package:flutter/material.dart';

/// Safety Core AI corporate palette.
/// Base surface is Tailwind-style "slate 900" (#0F172A) as mandated by the
/// design spec — everything else is tuned to sit on top of it with WCAG-AA
/// contrast for field use in direct sunlight.
class AppColors {
  AppColors._();

  // Core slate scale
  static const Color slate900 = Color(0xFF0F172A); // app background
  static const Color slate800 = Color(0xFF1E293B); // surfaces / cards
  static const Color slate700 = Color(0xFF334155); // dividers / outlines
  static const Color slate500 = Color(0xFF64748B); // secondary text/icons
  static const Color slate200 = Color(0xFFE2E8F0); // primary text on dark

  // Brand accent
  static const Color accent = Color(0xFF38BDF8); // cyan-400, links/CTA
  static const Color accentDark = Color(0xFF0284C7);

  // Severity / status semantics
  static const Color statusOpen = Color(0xFFEF4444); // red-500
  static const Color statusPendingVerification = Color(0xFFF59E0B); // amber-500
  static const Color statusClosed = Color(0xFF22C55E); // green-500

  static const Color severityLow = Color(0xFF60A5FA);
  static const Color severityMedium = Color(0xFFF59E0B);
  static const Color severityHigh = Color(0xFFF97316);
  static const Color severityCritical = Color(0xFFDC2626);

  static const Color emergencyRed = Color(0xFFB91C1C);

  static const Color offlineAmber = Color(0xFFF59E0B);
  static const Color syncedGreen = Color(0xFF22C55E);
}
