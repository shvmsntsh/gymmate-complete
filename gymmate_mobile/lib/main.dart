import 'package:flutter/material.dart';
import 'dart:async';
import 'home_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/invite_generator_page.dart';
import 'pages/invite_code_list_page.dart';
import 'pages/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(nextScreen: LoginPage()),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/home': (context) => HomePage(),
        '/invite-generator': (context) => InviteGeneratorPage(),
        '/invite': (context) => InviteGeneratorPage(),
        '/invite-list': (context) => InviteCodeListPage(),
      },
      onUnknownRoute: (settings) {
        debugPrint('❌ Unknown route: \${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('Unknown route: \${settings.name}')),
          ),
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00CFE8),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF00CFE8),
          secondary: Color(0xFF1E1E1E),
          surface: Color(0xFF1E1E1E),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.white54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00CFE8),
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00CFE8),
            textStyle: const TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }
}