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
import 'appearance_settings.dart' as app;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'notification_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  
  // Show local notification for background messages
  if (message.notification != null) {
    final RemoteNotification notification = message.notification!;
    await NotificationService.showLocalNotification(
      title: notification.title ?? 'Nil Shobdo',
      body: notification.body ?? 'New message',
      payload: message.data.toString(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase Initialize
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize timezones for notifications
  tz.initializeTimeZones();

  // Firebase App Check - Debug mode for development
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    webProvider: ReCaptchaV3Provider('6LfObLYrAAAAACQ5xR5h1tg3ejXpKFx_ZI9T1A-1'),
  );

  // Initialize Notification Service
  await _initializeNotificationService();

  runApp(const NilShobdoApp());
}

// In main.dart, update the _initializeNotificationService function:

// In main.dart, update the _initializeNotificationService function:

Future<void> _initializeNotificationService() async {
  try {
    // Initialize the notification service
    await NotificationService.initialize();
    
    print('Notification service initialized successfully');
    
    // Get FCM token
    final String? token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');
    
    // Check pending notifications
    final pending = await NotificationService.getPendingNotifications();
    print('Pending notifications: ${pending.length}');
    
    // Setup a periodic check for scheduled notifications (as a fallback)
    _setupScheduledNotificationHandler();
    
  } catch (e) {
    print('Error initializing notification service: $e');
  }
}

void _setupScheduledNotificationHandler() {
  // This is a fallback mechanism to handle scheduled notifications
  // In a real app, you'd use WorkManager or similar for more reliable scheduling
  print('Setting up scheduled notification handler...');
}

class NilShobdoApp extends StatelessWidget {
  const NilShobdoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final user = snapshot.data;
          
          if (user == null) {
            return const WelcomeScreen();
          } else if (!user.emailVerified) {
            return VerifyEmailScreen(userData: {
              'email': user.email,
              'uid': user.uid,
            });
          } else {
            return HomeScreen(userData: {
              'uid': user.uid,
              'email': user.email,
              'displayName': user.displayName,
            });
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return HomeScreen(userData: {
            'uid': user?.uid ?? '',
            'email': user?.email ?? '',
            'displayName': user?.displayName ?? '',
          });
        },
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final user = FirebaseAuth.instance.currentUser;
          return ChatScreen(
            userData: args ?? {
              'uid': user?.uid ?? '',
              'email': user?.email ?? '',
            },
          );
        },  
        '/exercise': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return RecommendationsScreen(
            p_userData: {},
            userId: user?.uid ?? 'default_user_id',
          );
        },
        '/profile': (context) => const ProfileScreen(),
        '/note': (context) => const MotivationScreen(),
        '/set': (context) => const SettingsScreen(),
        '/pro': (context) => const MentalHealthProfessionalsPage(),
        '/verify-email': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return VerifyEmailScreen(userData: {
            'email': user?.email ?? '',
            'uid': user?.uid ?? '',
          });
        },
        '/chathistory': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return ChatHistoryScreen(userData: {
            'uid': user?.uid ?? '',
            'email': user?.email ?? '',
          });
        },
        '/resetpass': (context) => ResetPasswordScreen(),
        '/resetemail': (context) => UpdateEmailScreen(),
        '/updateinfo': (context) => UpdateProfileScreen(),
        '/appearance': (context) => const app.AppearanceSettingsScreen(),
        '/book_preview': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return BookPreviewScreen(
            url: args['url'],
            title: args['title'],
          );
        },
      },
      onGenerateRoute: (settings) {
        // Handle routes that require arguments
        switch (settings.name) {
          case '/chat':
            final user = FirebaseAuth.instance.currentUser;
            return MaterialPageRoute(
              builder: (context) => ChatScreen(
                userData: {
                  'uid': user?.uid ?? '',
                  'email': user?.email ?? '',
                },
              ),
            );
          case '/home':
            final user = FirebaseAuth.instance.currentUser;
            return MaterialPageRoute(
              builder: (context) => HomeScreen(
                userData: {
                  'uid': user?.uid ?? '',
                  'email': user?.email ?? '',
                  'displayName': user?.displayName ?? '',
                },
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}