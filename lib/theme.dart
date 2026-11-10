import 'package:flutter/material.dart';

import 'logic/app_risk.dart';
import 'logic/checkup.dart';

class K {
  static const bg = Color(0xFF0B1220);
  static const panel = Color(0xFF131C2E);
  static const panel2 = Color(0xFF1B2740);
  static const line = Color(0xFF26344F);
  static const text = Color(0xFFE8EEF8);
  static const muted = Color(0xFF93A3BE);
  static const teal = Color(0xFF2DD4BF);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFF5A524);
  static const red = Color(0xFFE5484D);
  static const blue = Color(0xFF60A5FA);

  static Color forLevel(RiskLevel l) => switch (l) {
        RiskLevel.high => red,
        RiskLevel.medium => amber,
        RiskLevel.low => green,
      };

  static Color forStatus(CheckStatus s) => switch (s) {
        CheckStatus.ok => green,
        CheckStatus.warn => amber,
        CheckStatus.bad => red,
        CheckStatus.unknown => muted,
      };

  static Color forScore(int s) => s >= 85 ? green : (s >= 65 ? amber : red);

  static String levelText(RiskLevel l) => switch (l) {
        RiskLevel.high => 'อันตราย',
        RiskLevel.medium => 'น่าสงสัย',
        RiskLevel.low => 'ปกติ',
      };
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: K.teal, brightness: Brightness.dark, surface: K.bg),
    scaffoldBackgroundColor: K.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: K.bg, foregroundColor: K.text, elevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: K.panel,
      indicatorColor: K.teal.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, color: K.text)),
    ),
    textTheme: base.textTheme.apply(bodyColor: K.text, displayColor: K.text),
    dividerColor: K.line,
  );
}
