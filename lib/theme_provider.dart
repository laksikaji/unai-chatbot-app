import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  light,
  blue,
  dark,
  pink,
  green,
  red,
  orange,
  yellow,
  sky,
  purple,
}

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.blue;
  static const String _themeKey = 'app_theme';

  AppTheme get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  // Load saved theme from SharedPreferences
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_themeKey) ?? 'blue';
      _currentTheme = AppTheme.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => AppTheme.blue,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  // Change theme and save to SharedPreferences
  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme.name);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  // Get theme colors based on current theme
  ThemeColors get colors {
    switch (_currentTheme) {
      case AppTheme.light:
        return ThemeColors.light();
      case AppTheme.blue:
        return ThemeColors.blue();
      case AppTheme.dark:
        return ThemeColors.dark();
      case AppTheme.pink:
        return ThemeColors.pink();
      case AppTheme.green:
        return ThemeColors.green();
      case AppTheme.red:
        return ThemeColors.red();
      case AppTheme.orange:
        return ThemeColors.orange();
      case AppTheme.yellow:
        return ThemeColors.yellow();
      case AppTheme.sky:
        return ThemeColors.sky();
      case AppTheme.purple:
        return ThemeColors.purple();
    }
  }
}

class ThemeColors {
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color appBar;
  final Color drawer;
  final Color textPrimary;
  final Color textSecondary;
  final Color userBubble;
  final Color botBubble;
  final Color inputArea;
  final Color inputField;
  final Color dialogBackground;
  final Color buttonPrimary;
  final Color buttonSecondary;
  final Color divider;

  ThemeColors({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.appBar,
    required this.drawer,
    required this.textPrimary,
    required this.textSecondary,
    required this.userBubble,
    required this.botBubble,
    required this.inputArea,
    required this.inputField,
    required this.dialogBackground,
    required this.buttonPrimary,
    required this.buttonSecondary,
    required this.divider,
  });

  // Light Theme (สีขาว)
  factory ThemeColors.light() {
    return ThemeColors(
      backgroundStart: const Color(0xFFF5F7FA),
      backgroundEnd: const Color(0xFFE8EDF5),
      appBar: const Color(0xFFFFFFFF),
      drawer: const Color(0xFFFFFFFF),
      textPrimary: const Color(0xFF1F2937),
      textSecondary: const Color(0xFF6B7280),
      userBubble: const Color(0xFF6B7280),
      botBubble: const Color(0xFFE5E7EB),
      inputArea: const Color(0xFFFFFFFF),
      inputField: const Color(0xFFF3F4F6),
      dialogBackground: const Color(0xFFFFFFFF),
      buttonPrimary: const Color(0xFF6B7280),
      buttonSecondary: const Color(0xFF9CA3AF),
      divider: const Color(0xFFE5E7EB),
    );
  }

  // Blue Theme (สีน้ำเงิน - Current)
  factory ThemeColors.blue() {
    return ThemeColors(
      backgroundStart: const Color(0xFF0a1e5e),
      backgroundEnd: const Color(0xFF1a3a8a),
      appBar: const Color(0xFF1e3a8a),
      drawer: const Color(0xFF0a1e5e),
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
      userBubble: const Color(0xFF2563eb),
      botBubble: const Color(0xFF1e40af),
      inputArea: const Color(0xFF1e3a8a),
      inputField: const Color(0xFF0a1e5e),
      dialogBackground: const Color(0xFF0a1e5e),
      buttonPrimary: const Color(0xFF2563eb),
      buttonSecondary: const Color(0xFF1e40af),
      divider: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
    );
  }

  // Dark Theme (สีดำ)
  factory ThemeColors.dark() {
    return ThemeColors(
      backgroundStart: const Color(0xFF0F172A),
      backgroundEnd: const Color(0xFF1E293B),
      appBar: const Color(0xFF1E293B),
      drawer: const Color(0xFF0F172A),
      textPrimary: const Color(0xFFF1F5F9),
      textSecondary: const Color(0xFF94A3B8),
      userBubble: const Color(0xFF475569),
      botBubble: const Color(0xFF334155),
      inputArea: const Color(0xFF1E293B),
      inputField: const Color(0xFF0F172A),
      dialogBackground: const Color(0xFF1E293B),
      buttonPrimary: const Color(0xFF475569),
      buttonSecondary: const Color(0xFF64748B),
      divider: const Color(0xFF334155),
    );
  }

  // Pink Theme (สีชมพู)
  factory ThemeColors.pink() {
    // Pastel Pink Style
    return ThemeColors(
      backgroundStart: const Color(0xFFFFF0F5), // Lavender Blush
      backgroundEnd: const Color(0xFFFFE4E1), // Misty Rose
      appBar: const Color(0xFFFFC1CC), // Bubblegum Pink
      drawer: const Color(0xFFFFF0F5),
      textPrimary: const Color(
        0xFF880E4F,
      ), // Pink 900 (Deep Pink/Maroon for readability)
      textSecondary: const Color(0xFFAD1457), // Pink 800
      userBubble: const Color(0xFFFF4081), // Pink Accent
      botBubble: const Color(0xFFFFCCE0), // Pale Pink
      inputArea: const Color(0xFFFFF0F5),
      inputField: const Color(0xFFFFFFFF),
      dialogBackground: const Color(0xFFFFF0F5),
      buttonPrimary: const Color(0xFFD81B60), // Pink 600
      buttonSecondary: const Color(0xFFEC407A), // Pink 400
      divider: const Color(0xFFF8BBD0), // Pink 200
    );
  }

  // Green Theme (สีเขียวเข้ม)
  factory ThemeColors.green() {
    return ThemeColors(
      backgroundStart: const Color(0xFF1B5E20), // Green 900
      backgroundEnd: const Color(0xFF003300), // Dark Green
      appBar: const Color(0xFF2E7D32), // Green 800
      drawer: const Color(0xFF1B5E20),
      textPrimary: const Color(0xFFE8F5E9), // Green 50
      textSecondary: const Color(0xFFA5D6A7), // Green 200
      userBubble: const Color(0xFF43A047), // Green 600
      botBubble: const Color(0xFF2E7D32), // Green 800
      inputArea: const Color(0xFF1B5E20),
      inputField: const Color(0xFF388E3C), // Green 700
      dialogBackground: const Color(0xFF1B5E20),
      buttonPrimary: const Color(0xFF4CAF50), // Green 500
      buttonSecondary: const Color(0xFF2E7D32), // Green 800
      divider: const Color(0xFF4CAF50).withValues(alpha: 0.3),
    );
  }

  // Red Theme (สีแดง)
  factory ThemeColors.red() {
    return ThemeColors(
      backgroundStart: const Color(0xFFB71C1C), // Red 900
      backgroundEnd: const Color(0xFF880E4F), // Dark Red
      appBar: const Color(0xFFD32F2F), // Red 700
      drawer: const Color(0xFFB71C1C),
      textPrimary: const Color(0xFFFFEBEE), // Red 50
      textSecondary: const Color(0xFFEF9A9A), // Red 200
      userBubble: const Color(0xFFE53935), // Red 600
      botBubble: const Color(0xFFC62828), // Red 800
      inputArea: const Color(0xFFB71C1C),
      inputField: const Color(0xFFD32F2F), // Red 700
      dialogBackground: const Color(0xFFB71C1C),
      buttonPrimary: const Color(0xFFE53935), // Red 600
      buttonSecondary: const Color(0xFFC62828), // Red 800
      divider: const Color(0xFFE57373).withValues(alpha: 0.3),
    );
  }

  // Orange Theme (สีส้ม)
  factory ThemeColors.orange() {
    return ThemeColors(
      backgroundStart: const Color(0xFFE65100), // Orange 900
      backgroundEnd: const Color(0xFFBF360C), // Deep Orange 900
      appBar: const Color(0xFFF57C00), // Orange 700
      drawer: const Color(0xFFE65100),
      textPrimary: const Color(0xFFFFF3E0), // Orange 50
      textSecondary: const Color(0xFFFFCC80), // Orange 200
      userBubble: const Color(0xFFFB8C00), // Orange 600
      botBubble: const Color(0xFFEF6C00), // Orange 800
      inputArea: const Color(0xFFE65100),
      inputField: const Color(0xFFF57C00), // Orange 700
      dialogBackground: const Color(0xFFE65100),
      buttonPrimary: const Color(0xFFFB8C00), // Orange 600
      buttonSecondary: const Color(0xFFEF6C00), // Orange 800
      divider: const Color(0xFFFFB74D).withValues(alpha: 0.3),
    );
  }

  // Yellow Theme (สีเหลือง)
  factory ThemeColors.yellow() {
    return ThemeColors(
      backgroundStart: const Color(0xFFFFFDE7), // Yellow 50 (Lighter)
      backgroundEnd: const Color(0xFFFFF9C4), // Yellow 100 (Light)
      appBar: const Color(0xFFFFEA00), // Yellow Accent
      drawer: const Color(0xFFFFD600),
      textPrimary: const Color(0xFF263238), // Blue Grey 900
      textSecondary: const Color(0xFF37474F), // Blue Grey 800
      userBubble: const Color(0xFFFFC107), // Amber 500
      botBubble: const Color(0xFFFFF8E1), // Amber 50
      inputArea: const Color(0xFFFFD600),
      inputField: const Color(0xFFFFF9C4), // Yellow 100
      dialogBackground: const Color(0xFFFFD600),
      buttonPrimary: const Color(0xFFFFB300), // Amber 700
      buttonSecondary: const Color(0xFFFBC02D), // Yellow 800
      divider: const Color(0xFFFFAB00).withValues(alpha: 0.3),
    );
  }

  // Sky Theme (สีฟ้า)
  factory ThemeColors.sky() {
    return ThemeColors(
      backgroundStart: const Color(0xFF0288D1), // Light Blue 700
      backgroundEnd: const Color(0xFF01579B), // Light Blue 900
      appBar: const Color(0xFF03A9F4), // Light Blue 500
      drawer: const Color(0xFF0288D1),
      textPrimary: const Color(0xFFE1F5FE), // Light Blue 50
      textSecondary: const Color(0xFFB3E5FC), // Light Blue 100
      userBubble: const Color(0xFF29B6F6), // Light Blue 400
      botBubble: const Color(0xFF004C8C), // Darker Blue for AI Bubble
      inputArea: const Color(0xFF0288D1),
      inputField: const Color(0xFF0277BD), // Light Blue 800
      dialogBackground: const Color(0xFF0288D1),
      buttonPrimary: const Color(0xFF039BE5), // Light Blue 600
      buttonSecondary: const Color(0xFF01579B), // Light Blue 900
      divider: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
    );
  }

  // Purple Theme (สีม่วง)
  factory ThemeColors.purple() {
    return ThemeColors(
      backgroundStart: const Color(0xFF6A1B9A), // Purple 800
      backgroundEnd: const Color(0xFF4A148C), // Purple 900
      appBar: const Color(0xFF7B1FA2), // Purple 700
      drawer: const Color(0xFF6A1B9A),
      textPrimary: const Color(0xFFF3E5F5), // Purple 50
      textSecondary: const Color(0xFFE1BEE7), // Purple 100
      userBubble: const Color(0xFF9C27B0), // Purple 500
      botBubble: const Color(0xFF6A1B9A), // Purple 800
      inputArea: const Color(0xFF6A1B9A),
      inputField: const Color(0xFF4A148C), // Purple 900
      dialogBackground: const Color(0xFF6A1B9A),
      buttonPrimary: const Color(0xFF8E24AA), // Purple 600
      buttonSecondary: const Color(0xFF4A148C), // Purple 900
      divider: const Color(0xFFBA68C8).withValues(alpha: 0.3),
    );
  }
}
