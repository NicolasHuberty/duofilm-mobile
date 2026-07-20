import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design « Velours Nocturne » — nuit encrée, rouge velours, doré projecteur.
class DF {
  static const bg = Color(0xFF161122);
  static const surface = Color(0xFF211A33);
  static const muted = Color(0xFF2C2344);
  static const accent = Color(0xFFE4564E); // rouge velours
  static const accentInk = Color(0xFFFFF3EE);
  static const secondary = Color(0xFFF0B95A); // doré
  static const secondaryInk = Color(0xFF2B1D0E);
  static const teal = Color(0xFF57B8AE);
  static const ink = Color(0xFFF4EFFA);
  static const inkSoft = Color(0xFF9C90B8);
  static const inkBody = Color(0xFFC9BFDD);

  static TextStyle serif(double size, {FontWeight w = FontWeight.w600, Color? c}) =>
      GoogleFonts.fraunces(fontSize: size, fontWeight: w, color: c ?? ink, height: 1.1);
  static TextStyle sans(double size, {FontWeight w = FontWeight.w500, Color? c}) =>
      GoogleFonts.outfit(fontSize: size, fontWeight: w, color: c ?? ink);

  static ThemeData theme() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent, secondary: secondary, surface: surface, brightness: Brightness.dark),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink),
    );
  }
}
