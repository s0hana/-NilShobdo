import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'notification_time_manager.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔔 Handling a background message: ${message.messageId}");
  
  // Show local notification for background messages
  if (message.notification != null) {
    final RemoteNotification notification = message.notification!;
    await NotificationService.handleBackgroundNotification(message);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Starting Nil Shobdo App...');
  
  try {
    // Firebase Initialize
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    // Initialize timezones for notifications
    tz.initializeTimeZones();
    print('✅ Timezones initialized');

    // Firebase App Check - Debug mode for development
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
    print('✅ Firebase App Check activated');

    // Initialize Notification Service
    await _initializeNotificationService();
    
    print('🎉 All services initialized successfully');

  } catch (e) {
    print('❌ Error during initialization: $e');
  }

  runApp(const NilShobdoApp());
}

Future<void> _initializeNotificationService() async {
  try {
    print('🔔 Initializing Notification Service...');
    
    // Initialize the main notification service
    await NotificationService.initialize();
    
    // Setup Firebase messaging
    await _setupFirebaseMessaging();
    
    // ✅ START DAILY NOTIFICATION SERVICE
    await _startDailyNotificationService();
    
    print('✅ Notification service initialized successfully');
    
  } catch (e) {
    print('❌ Error initializing notification service: $e');
  }
}

// ✅ NEW: Start daily notification service
Future<void> _startDailyNotificationService() async {
  try {
    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('👤 User not logged in, skipping notification service start');
      return;
    }

    // Get user's saved notification times from SharedPreferences
    final notificationTimes = await NotificationTimeManager.getNotificationTimes();
    final enabledTimes = notificationTimes
        .where((time) => time.enabled)
        .map((time) => time.time)
        .toList();
    
    if (enabledTimes.isEmpty) {
      print('🔕 No enabled notification times found');
      return;
    }
    
    print('⏰ Starting daily notifications with ${enabledTimes.length} times:');
    for (final time in enabledTimes) {
      print('   - ${_formatTime(time)}');
    }
    
    // Start both services for maximum reliability
    await NotificationService.startDailyNotifications(enabledTimes);
    await NotificationService.updateScheduledNotifications();
    
    print('✅ Daily notification service started successfully');
    
  } catch (e) {
    print('❌ Error starting daily notification service: $e');
  }
}

String _formatTime(TimeOfDay time) {
  final hour = time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

Future<void> _setupFirebaseMessaging() async {
  try {
    // Request notification permissions
    final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    print('📱 Notification permission: ${settings.authorizationStatus}');

    // Get FCM token
    final String? token = await FirebaseMessaging.instance.getToken();
    print('🔑 FCM Token: $token');
    
    // Save FCM token to user document if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await NotificationService.saveFCMToken(token);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📲 Foreground message received: ${message.messageId}');
      
      // Show local notification when app is in foreground
      if (message.notification != null) {
        final notification = message.notification!;
        NotificationService.showLocalNotification(
          title: notification.title ?? 'Nil Shobdo',
          body: notification.body ?? 'New message',
          payload: message.data.toString(),
        );
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from notification: ${message.data}');
      _handleNotificationOpen(message);
    });

    print('✅ Firebase messaging setup completed');

  } catch (e) {
    print('❌ Error setting up Firebase messaging: $e');
  }
}

void _handleNotificationOpen(RemoteMessage message) {
  // Handle navigation when app is opened from notification
  final data = message.data;
  print('🎯 Notification opened with data: $data');
  
  // You can add specific navigation logic here based on notification type
  if (data['type'] == 'motivation') {
    Get.to(() => const MotivationScreen());
  } else if (data['type'] == 'chat') {
    final user = FirebaseAuth.instance.currentUser;
    Get.to(() => ChatScreen(
      userData: {
        'uid': user?.uid ?? '',
        'email': user?.email ?? '',
      },
    ));
  }
}

class NilShobdoApp extends StatelessWidget {
  const NilShobdoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nil Shobdo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppLifecycleManager(), // ✅ Changed to lifecycle manager
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
            pUserData: {},
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

// ✅ NEW: App Lifecycle Manager to handle notification service
class AppLifecycleManager extends StatefulWidget {
  const AppLifecycleManager({super.key});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App resumed - restarting notification service');
        _restartNotificationService();
        break;
      case AppLifecycleState.paused:
        print('📱 App paused - ensuring system notifications are scheduled');
        _ensureSystemNotifications();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Future<void> _initializeNotifications() async {
    // Small delay to ensure Firebase is fully initialized
    await Future.delayed(const Duration(seconds: 2));
    await _restartNotificationService();
  }

  Future<void> _restartNotificationService() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final notificationTimes = await NotificationTimeManager.getNotificationTimes();
        final enabledTimes = notificationTimes
            .where((time) => time.enabled)
            .map((time) => time.time)
            .toList();
        
        if (enabledTimes.isNotEmpty) {
          await NotificationService.restartWithNewTimes(enabledTimes);
          print('🔄 Notification service restarted with ${enabledTimes.length} times');
        }
      }
    } catch (e) {
      print('❌ Error restarting notification service: $e');
    }
  }

  Future<void> _ensureSystemNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await NotificationService.updateScheduledNotifications();
        print('✅ System notifications ensured');
      }
    } catch (e) {
      print('❌ Error ensuring system notifications: $e');
    }
  }
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
  return StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Loading Nil Shobdo...'),
              ],
            ),
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
        // Use FutureBuilder to fetch user data from Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error: ${userSnapshot.error}'),
                ),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User document doesn't exist, create one and navigate to HomeScreen
              _createUserDocument(user).then((_) {
                // After creating document, you can navigate or rebuild
                // Since we're in build method, we'll let the FutureBuilder rebuild
              });
              
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('Setting up your profile...'),
                    ],
                  ),
                ),
              );
            }

            // User document exists, proceed to HomeScreen with full data
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            
            return HomeScreen(userData: {
              'uid': user.uid,
              'email': user.email,
              'displayName': user.displayName,
              ...userData, // Spread the Firestore data
            });
          },
        );
      }
    },
  );
}

// Helper function to create user document
Future<void> _createUserDocument(User user) async {
  try {
    await _firestore.collection('users').doc(user.uid).set({
      'fullName': user.displayName ?? 'User',
      'email': user.email ?? '',
      'photoURL': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print("Error creating user document: $e");
  }
}
}