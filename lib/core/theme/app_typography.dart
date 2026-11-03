import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale — pulled from Figma "06 Typography" (system v1.2).
///
/// Two-tier pairing, all from the bundled font assets (no network font loading):
/// - Editorial (Display/H1/H2): Fraunces.
/// - Standard UI (H3 and smaller): Plus Jakarta Sans.
/// - Arabic fallback for both: IBM Plex Sans Arabic.
/// Dense data/metrics (prices, ref IDs) get IBM Plex Arabic on the Arabic
/// side; the Latin side stays Inter, so no separate English style is needed
/// today.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => TextTheme(
    // Display — 48/SemiBold/LH1.2
    displayLarge: TextStyle(
      fontFamily: 'Fraunces',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 48,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.ink,
    ),
    // H1 — 36/SemiBold/LH1.2
    headlineLarge: TextStyle(
      fontFamily: 'Fraunces',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 36,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.ink,
    ),
    // H2 — 28/SemiBold/LH1.3
    headlineMedium: TextStyle(
      fontFamily: 'Fraunces',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AppColors.ink,
    ),
    // H3 — 22/Medium/LH1.4 (standard UI tier starts here)
    headlineSmall: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 22,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: AppColors.ink,
    ),
    // H4 — 18/Medium/LH1.4
    titleLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: AppColors.ink,
    ),
    titleSmall: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: AppColors.charcoal,
    ),
    // Body Large — 18/Regular/LH1.6
    bodyLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.6,
      color: AppColors.charcoal,
    ),
    // Body — 16/Regular/LH1.6
    bodyMedium: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
      color: AppColors.charcoal,
    ),
    // Body Small — 14/Regular/LH1.5
    bodySmall: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.slate,
    ),
    // Button — 16/SemiBold/LH1.2
    labelLarge: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.ink,
    ),
    // Label — 12/SemiBold/LH1.2/Uppercase (apply textTransform at call site)
    labelMedium: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.4,
      color: AppColors.slate,
    ),
    // Caption — 12/Regular/LH1.4
    labelSmall: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.mist,
    ),
  );
}
