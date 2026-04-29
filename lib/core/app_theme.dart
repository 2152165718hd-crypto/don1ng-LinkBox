import 'package:flutter/material.dart';

class LinkBoxTheme {
  const LinkBoxTheme._();

  static ThemeData light() {
    const seed = Color(0xFF176B87);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        isDense: true,
      ),
    );
  }
}
