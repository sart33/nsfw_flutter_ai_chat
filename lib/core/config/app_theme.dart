import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

// ── UI / layout breakpoints ───────────────────────────────────────────
  static const double kDesktopBreakpoint = 600.0;

  static const double kContentMaxWidth = 960.0;

  static const bodyStyle = TextStyle(
    fontSize: 16,
    color: AppTheme.textPrimary,
  );
  // ── Colour palette ────────────────────────────────────────────────────
  static const Color background    = Color(0xFF000000);
  static const Color surface       = Color(0xFF111111);
  static const Color cardBg        = Color(0xFF1A1A1E); // карточки на home/settings
  static const Color iconBg        = Color(0xFF28183F); // фон иконок в карточках
  static const Color userBubble    = Color(0xFF333333);
  static const Color supportBubble    = Color(0xFF242426);
  static const Color userIcon      = Color(0xFF919191);
  static const Color aiBubble      = Color(0xFF111111);
  static const Color primaryAccent = Color(0xFFAA7EF4); // фиолетовый акцент
  static const Color accentVivid   = Color(0xBE7C3AED);
  static const Color accentVividButton   = Color(0xBE8B4FF4);
  static const Color bottomSheetBackground   = Color(0xFF0D0D10);
  // FAB / иконки AppBar
  static const Color accentVividInputBorder   = Color(0x7C39FF6A); // FAB / иконки AppBar
  static const Color accentLight   = Color(0xFFAB76FF); // иконки в карточках
  static const Color cardBorder    = Color(0xFF393948); // бордер карточек
  static const Color lightBorder    = Color(0xFF6F6F88); // бордер карточек
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textChatSupport = Color(0xFFBDBDBD);

  static const Color textThird     = Color(0xFFD0D0D0);
  static const Color error         = Color(0xFFB71C1C);
  static const Color success       = Color(0xFF068733);
  static const Color warning       = Color(0xFFE65100);
  static const Color textWarning       = Color(0xFFD97436);
  static const Color unVerified       = Color(0xFFD97436);

  // ── Shared card decoration ────────────────────────────────────────────
  /// Используй для всех карточек на Settings / Home
  static BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: cardBorder, width: 1),
  );

  // ── ThemeData ─────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primaryAccent,
      surface: surface,
      onPrimary: Colors.black,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: cardBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: const TextStyle(color: textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentVivid,
      foregroundColor: Colors.white,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: primaryAccent,
      thumbColor: Colors.white,
      inactiveTrackColor: cardBorder,
      overlayColor: Color(0x22AA7EF4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
      states.contains(WidgetState.selected) ? primaryAccent : cardBorder),
    ),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textPrimary),
      bodySmall:  TextStyle(color: textSecondary),
    ),
  );
}