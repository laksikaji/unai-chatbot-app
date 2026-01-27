import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/supabase_service.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/admin_dashboard.dart';

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
          final isAdmin = await SupabaseService().isAdmin();
          final targetScreen = isAdmin
              ? const AdminDashboard()
              : const ChatScreen(isGuest: false);

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'UNAi Chatbot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
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
                if (snapshot.hasData && snapshot.data == true) {
                  return const AdminDashboard();
                }
                return const ChatScreen(isGuest: false);
              },
            )
          : const HomeScreen(),
    );
  }
}
