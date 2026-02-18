import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, blue, dark, pink, green }

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
}
