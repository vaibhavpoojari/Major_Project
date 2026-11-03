import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'services/localization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Mock DB / Session Persistence & Localization
  await DatabaseService.init();
  await AppLocalization.init();

  // Robust initialization of Firebase
  try {
    await Firebase.initializeApp();
    print("Firebase successfully initialized");
  } catch (e) {
    print("Firebase initialization skipped (Running in Mock Fallback Mode): $e");
  }

  runApp(const AccidentGuardApp());
}

class AccidentGuardApp extends StatelessWidget {
  const AccidentGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accident Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep slate navy
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE11D48), // Emergency Crimson
          onPrimary: Colors.white,
          secondary: Color(0xFF38BDF8), // Cyan Blue
          onSecondary: Colors.white,
          surface: Color(0xFF161E2E), // Card Surface
          onSurface: Colors.white,
          surfaceContainerHighest: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
          onError: Colors.white,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
          displayMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18),
          titleMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
          bodyLarge: TextStyle(fontFamily: 'Inter', color: Color(0xFFE2E8F0), fontSize: 15),
          bodyMedium: TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 13.5),
          labelLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF161E2E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF26334D), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIconColor: const Color(0xFF94A3B8),
          suffixIconColor: const Color(0xFF94A3B8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF161E2E),
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF26334D)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentTextStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Colors.white),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF26334D),
          thickness: 1,
          space: 24,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
