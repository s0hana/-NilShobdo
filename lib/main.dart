import 'package:flutter/material.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart'; 
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'chat_history_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'chat_sceen.dart';
import 'exercise_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'settings.dart';
import 'professionals_screen.dart';
import 'package:get/get.dart';
import 'verify_email_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reset_password_screen.dart';
import 'reset_email.dart';
import 'profile_update_screen.dart';
import 'book_preview.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase Initialize
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firebase App Check - Debug mode for development
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    webProvider: ReCaptchaV3Provider('6LfObLYrAAAAACQ5xR5h1tg3ejXpKFx_ZI9T1A-1'),
  );

  runApp(const NilShobdoApp());
}

class NilShobdoApp extends StatelessWidget {
  const NilShobdoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => HomeScreen(userData: {}),
        '/chat': (context) => const ChatScreen(userData: {},),  
        '/exercise': (context) => const RecommendationsScreen(userId: 'AYPqR0TqB4cjbZeofNIPYAOTtWO2'),
        '/profile': (context) => const ProfileScreen(),
        '/note': (context) => const MotivationScreen(),
        '/set' : (context) => const SettingsScreen(),
        '/pro' : (context) => const MentalHealthProfessionalsPage(),
        '/verify-email': (context) => VerifyEmailScreen(userData: {}),
        '/chathistory': (context) => ChatHistoryScreen(userData: {}),
        '/resetpass': (context) => ResetPasswordScreen(),
        '/resetemail': (context) => UpdateEmailScreen(),
        '/updateinfo': (context) => UpdateProfileScreen(),
        '/book_preview': (context) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return BookPreviewScreen(
        url: args['url'],
        title: args['title'],
      );
    },
      },
    );
  }
}