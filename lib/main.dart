import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'screens/supabase_service.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService().initialize();

  runApp(const UNAIChatbotApp());
}

class UNAIChatbotApp extends StatefulWidget {
  const UNAIChatbotApp({super.key});

  @override
  State<UNAIChatbotApp> createState() => _UNAIChatbotAppState();
}

class _UNAIChatbotAppState extends State<UNAIChatbotApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    SupabaseService().client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      debugPrint('🔔 Auth Event: $event');

      if (event == AuthChangeEvent.signedOut) {
        debugPrint('User signed out, navigating to home...');

        Future.delayed(Duration.zero, () {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        });
      } else if (event == AuthChangeEvent.signedIn) {
        debugPrint('User signed in, checking role...');

        Future.delayed(Duration.zero, () async {
          await SupabaseService()
              .isAdmin(); // ตรวจสอบ role แต่ไม่ใช้ผลในการ redirect
          const targetScreen = ChatScreen(isGuest: false);

          if (mounted) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => targetScreen),
              (route) => false,
            );
          }
        });
      }
    });
  }

  TextTheme _buildTextTheme(TextTheme base) {
    // Start with Inter (English)
    final interTheme = GoogleFonts.interTextTheme(base);
    // Get Taviraj family for fallback
    final thaiFontFamily = GoogleFonts.taviraj().fontFamily;

    // Helper to add fallback
    TextStyle? addFallback(TextStyle? style) {
      if (style == null) return null;
      return style.copyWith(
        fontFamilyFallback: [if (thaiFontFamily != null) thaiFontFamily],
      );
    }

    return interTheme.copyWith(
      displayLarge: addFallback(interTheme.displayLarge),
      displayMedium: addFallback(interTheme.displayMedium),
      displaySmall: addFallback(interTheme.displaySmall),
      headlineLarge: addFallback(interTheme.headlineLarge),
      headlineMedium: addFallback(interTheme.headlineMedium),
      headlineSmall: addFallback(interTheme.headlineSmall),
      titleLarge: addFallback(interTheme.titleLarge),
      titleMedium: addFallback(interTheme.titleMedium),
      titleSmall: addFallback(interTheme.titleSmall),
      bodyLarge: addFallback(interTheme.bodyLarge),
      bodyMedium: addFallback(interTheme.bodyMedium),
      bodySmall: addFallback(interTheme.bodySmall),
      labelLarge: addFallback(interTheme.labelLarge),
      labelMedium: addFallback(interTheme.labelMedium),
      labelSmall: addFallback(interTheme.labelSmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'UNAi Chatbot',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          textTheme: _buildTextTheme(
            ThemeData(brightness: Brightness.light).textTheme,
          ),
          useMaterial3: true,
        ),
        home: SupabaseService().isLoggedIn
            ? FutureBuilder<bool>(
                future: SupabaseService().isAdmin(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  // Admin และ User ทั่วไป เข้าหน้า Chat ก่อนเสมอ
                  return const ChatScreen(isGuest: false);
                },
              )
            : const HomeScreen(),
      ),
    );
  }
}
