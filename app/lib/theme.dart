import 'package:flutter/material.dart';

/// Brilho efetivo da interface (claro/escuro). É a fonte da verdade tanto para
/// o [ThemeData] do MaterialApp quanto para as cores fixas de [AppColors], que
/// são lidas como getters para acompanharem a troca de tema em tempo real.
///
/// `main.dart` mantém este valor sincronizado com a escolha do usuário
/// (sistema / claro / escuro) e com o brilho do sistema.
final ValueNotifier<bool> appIsDark = ValueNotifier<bool>(true);

/// Preferência de tema escolhida pela pessoa (persistida).
enum AppThemeChoice { system, light, dark }

extension AppThemeChoiceX on AppThemeChoice {
  String get label => switch (this) {
        AppThemeChoice.system => 'Do sistema',
        AppThemeChoice.light => 'Claro',
        AppThemeChoice.dark => 'Escuro',
      };

  static AppThemeChoice fromName(String? s) => AppThemeChoice.values.firstWhere(
        (e) => e.name == s,
        orElse: () => AppThemeChoice.system,
      );
}

/// Paleta do MIAU NET. Cada cor devolve a variante clara ou escura conforme
/// [appIsDark]. Por serem getters, deixaram de ser `const`.
class AppColors {
  static bool get _d => appIsDark.value;

  static Color get bg => _d ? const Color(0xFF07080B) : const Color(0xFFF4F5F7);
  static Color get card =>
      _d ? const Color(0xFF101218) : const Color(0xFFFFFFFF);
  static Color get surface1 =>
      _d ? const Color(0xFF14161E) : const Color(0xFFFFFFFF);
  static Color get surface2 =>
      _d ? const Color(0xFF1B1E28) : const Color(0xFFEEF0F4);
  static Color get surface3 =>
      _d ? const Color(0xFF232733) : const Color(0xFFE1E4EA);
  static Color get accent =>
      _d ? const Color(0xFFFFC93C) : const Color(0xFFB97800);
  static Color get accent2 =>
      _d ? const Color(0xFFFF9A2E) : const Color(0xFFE0730E);
  static Color get ok =>
      _d ? const Color(0xFF3DDC97) : const Color(0xFF12885A);
  static Color get bad =>
      _d ? const Color(0xFFFF5D5D) : const Color(0xFFD23838);
  static Color get text =>
      _d ? const Color(0xFFF2F4F8) : const Color(0xFF13151B);
  static Color get muted =>
      _d ? const Color(0xFF8B92A4) : const Color(0xFF5B6472);
  static Color get line =>
      _d ? const Color(0x14FFFFFF) : const Color(0x14000000);

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

ThemeData buildTheme({bool dark = true}) {
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final accent = dark ? const Color(0xFFFFC93C) : const Color(0xFFB97800);
  final accent2 = dark ? const Color(0xFFFF9A2E) : const Color(0xFFE0730E);
  final bg = dark ? const Color(0xFF07080B) : const Color(0xFFF4F5F7);
  final card = dark ? const Color(0xFF101218) : const Color(0xFFFFFFFF);
  final surface1 = dark ? const Color(0xFF14161E) : const Color(0xFFFFFFFF);
  final surface2 = dark ? const Color(0xFF1B1E28) : const Color(0xFFEEF0F4);
  final surface3 = dark ? const Color(0xFF232733) : const Color(0xFFE1E4EA);
  final textColor = dark ? const Color(0xFFF2F4F8) : const Color(0xFF13151B);
  final muted = dark ? const Color(0xFF8B92A4) : const Color(0xFF5B6472);
  final line = dark ? const Color(0x14FFFFFF) : const Color(0x14000000);
  final appBarBg = dark ? const Color(0xFF0D0F15) : const Color(0xFFFFFFFF);
  final bad = dark ? const Color(0xFFFF5D5D) : const Color(0xFFD23838);

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      secondary: accent2,
      surface: card,
      onPrimary: dark ? const Color(0xFF171207) : const Color(0xFFFFFFFF),
      onSurface: textColor,
      error: bad,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: dark ? const Color(0xFFDFE3EC) : const Color(0xFF2A2E38)),
    ),
    dividerColor: line,
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    textTheme: base.textTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: surface1,
      textColor: textColor,
      iconColor: muted,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: dark ? const Color(0xFF171207) : Colors.white,
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: accent,
      unselectedLabelColor: muted,
      indicatorColor: accent,
      dividerColor: line,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      unselectedLabelStyle: const TextStyle(fontSize: 13.5),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: surface3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? accent
            : (dark ? const Color(0xFF9AA2B4) : const Color(0xFFB4B9C4)),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.35)
            : surface3,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface3,
      contentTextStyle: TextStyle(color: textColor),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
