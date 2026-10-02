import 'package:flutter/material.dart';

/// Pitch Dark Precision — Flat Minimalist Design System Color Palette.
///
/// Built on high-contrast pitch obsidian, flat slate surfaces, razor-thin
/// hairline dividers, and vibrant flat signal tallies. Zero blurry glass
/// or fuzzy drop shadows.
class AppColors {
  AppColors._();

  // Foundation Neutrals (Refined Obsidian & Muted Slate)
  static const Color background = Color(0xFF0F1015);
  static const Color backgroundDeep = Color(0xFF0A0B0E);
  static const Color obsidianBase = background;
  static const Color surface = Color(0xFF16181F);
  static const Color surfaceElevated = Color(0xFF1E212B);
  static const Color surfaceBorder = Color(0xFF282C37);
  static const Color surfaceBorderBold = Color(0xFF383E4E);
  static const Color surfaceBorderActive = surfaceBorderBold;

  // Broadcast Signal Tallies (Muted Minimalist Precision)
  static const Color liveRed = Color(0xFFD95D5D); // Muted Crimson — Program / Live Transmission
  static const Color previewAmber = Color(0xFFD49B44); // Muted Ochre — Preview / Standby Staging
  static const Color accentCyan = Color(0xFF4CA6B8); // Muted Slate Cyan — Active Interactive Controls

  // Functional Aliases
  static const Color primary = liveRed;
  static const Color bauhausRed = liveRed;
  static const Color bauhausYellow = previewAmber;
  static const Color bauhausBlue = accentCyan;

  // Auxiliary Functional Accents (Muted & Balanced)
  static const Color connectedGreen = Color(0xFF4FA878); // Muted Sage Emerald — Connection State
  static const Color accentBlue = Color(0xFF5680B8); // Muted Slate Denim
  static const Color accentPurple = Color(0xFF8572A8); // Muted Dusk Lavender
  static const Color accentOrange = Color(0xFFC87848); // Muted Terracotta

  // Audio VU Meter Levels (Muted Solid Signal Steps)
  static const Color vuGreen = Color(0xFF4FA878);
  static const Color vuYellow = Color(0xFFD49B44);
  static const Color vuRed = Color(0xFFD95D5D);

  // High-Contrast Typography & Metadata
  static const Color textPrimary = Color(0xFFECEFF4); // Soft Chalk White
  static const Color textSecondary = Color(0xFF909AA8); // Muted Cool Slate
  static const Color textMuted = Color(0xFF5D6675); // Quiet Metadata Slate

  // Flat structural transitions (solid muted tones)
  static const LinearGradient liveGradient = LinearGradient(
    colors: [Color(0xFFD95D5D), Color(0xFFC04B4B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient previewGradient = LinearGradient(
    colors: [Color(0xFFD49B44), Color(0xFFBC8430)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient vuGradient = LinearGradient(
    colors: [vuGreen, vuYellow, vuRed],
    stops: [0.65, 0.85, 1.0],
  );
}
