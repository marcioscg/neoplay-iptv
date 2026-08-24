import 'package:flutter/material.dart';

/// Paleta do NEOPLAY (mesma do mapa de telas).
class AppColors {
  static const bg = Color(0xFF07080B);
  static const card = Color(0xFF101218);
  static const surface1 = Color(0xFF14161E);
  static const surface2 = Color(0xFF1B1E28);
  static const surface3 = Color(0xFF232733);
  static const accent = Color(0xFFFFC93C);
  static const accent2 = Color(0xFFFF9A2E);
  static const ok = Color(0xFF3DDC97);
  static const bad = Color(0xFFFF5D5D);
  static const text = Color(0xFFF2F4F8);
  static const muted = Color(0xFF8B92A4);
  static const line = Color(0x14FFFFFF);

  /// Gradientes usados nos logos/capas quando não há imagem.
  static const artGradients = <List<Color>>[
    [Color(0xFFF0A32B), Color(0xFFA8451F)],
    [Color(0xFF5B8CFF), Color(0xFF2B1F6B)],
    [Color(0xFF3DDC97), Color(0xFF0F5C4A)],
    [Color(0xFFFF5D8F), Color(0xFF5C1533)],
    [Color(0xFFA97BFF), Color(0xFF331A63)],
    [Color(0xFF31C7D6), Color(0xFF124255)],
  ];

  static List<Color> artFor(String seed) =>
      artGradients[seed.hashCode.abs() % artGradients.length];
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.card,
      onPrimary: const Color(0xFF171207),
      error: AppColors.bad,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D0F15),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Color(0xFFDFE3EC)),
    ),
    dividerColor: AppColors.line,
    dividerTheme:
        const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: AppColors.surface1,
      textColor: AppColors.text,
      iconColor: AppColors.muted,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF171207),
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.accent,
      dividerColor: AppColors.line,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      unselectedLabelStyle: TextStyle(fontSize: 13.5),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surface3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.accent
            : const Color(0xFF9AA2B4),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.accent.withValues(alpha: 0.35)
            : AppColors.surface3,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface3,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
