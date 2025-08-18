import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'chat_sceen.dart';
import 'exercise_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'settings.dart';
import 'professionals_screen.dart';
void main() {
  runApp(const NilShobdoApp());
}

class NilShobdoApp extends StatelessWidget {
  const NilShobdoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/chat': (context) => const ChatScreen(),  
        '/exercise': (context) => const ExerciseScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/note': (context) => const MotivationScreen(),
        '/set' : (context) => const SettingsScreen(),
        '/pro' : (context) => const MentalHealthProfessionalsPage(),
      },
    );
  }
}
