
import 'package:flutter/material.dart';

abstract final class AppTheme {
  AppTheme._();

  // ── Paleta institucional ──────────────────────────────────────────────────

  /// Verde institucional IMSS Bienestar.
  static const Color verdeInstitucional = Color(0xFF006657);

  /// Oro institucional IMSS Bienestar.
  static const Color oroInstitucional = Color(0xFFBC955C);

  /// Guinda institucional IMSS Bienestar.
  static const Color guindaInstitucional = Color(0xFF691C32);

  /// Blanco roto — fondo general de pantallas.
  static const Color fondoClaro = Color(0xFFFBFBFB);

  /// Color de advertencia — timer en zona de precaución.
  static const Color advertencia = Colors.orange;

  // ── ThemeData principal ───────────────────────────────────────────────────

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: verdeInstitucional,
      primary: verdeInstitucional,
      secondary: oroInstitucional,
      tertiary: guindaInstitucional,
    ),
    scaffoldBackgroundColor: fondoClaro,
    appBarTheme: const AppBarTheme(
      backgroundColor: verdeInstitucional,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      prefixIconColor: verdeInstitucional,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: verdeInstitucional,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: verdeInstitucional,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );

  // ── Colores del timer de inactividad ─────────────────────────────────────

  /// Color del timer según los segundos restantes.
  static Color timerColor(int remainingSeconds) {
    if (remainingSeconds <= 30) return guindaInstitucional;
    if (remainingSeconds <= 60) return advertencia;
    return verdeInstitucional;
  }
}
