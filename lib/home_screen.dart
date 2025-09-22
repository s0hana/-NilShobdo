import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_sceen.dart';
import 'exercise_screen.dart';
import 'profile_screen.dart';
import 'professionals_screen.dart';
import 'settings.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  HomeScreen({super.key, required this.userData}); 

  final List<String> motivationalMessages = [
    "Believe in yourself! 💪",
    "Every day is a fresh start 🌅",
    "Stay positive, work hard, make it happen ✨",
    "Your only limit is your mind 🧠",
    "Push yourself, because no one else will do it for you 🚀",
    "Dream it. Wish it. Do it. 🌟",
    "Little progress each day adds up to big results 📈",
  ];

  @override
  Widget build(BuildContext context) {
    final randomMessage = motivationalMessages[Random().nextInt(motivationalMessages.length)];

    final userName = userData['fullName'] ?? 'User'; 
    final email = userData['email'] ?? ' ';   
    final photoUrl = userData['photoURL'];             

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFFBAE0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.blue, width: 2),
                  ),
                  color: Color(0xFF2196F3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/set");
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/note');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Welcome Message
              Center(
                child: Column(
                  children: [
                    if (photoUrl != null)
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(photoUrl),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      "Hi, $userName!\nWelcome Back!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 200),

                    // Motivational Message Box
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          color: Colors.white70,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                          child: Text(
                            randomMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 🔹 Bottom Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.blue, width: 2),
                  ),
                  color: Color(0xFF2196F3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(userData: userData),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/icons/4616759.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.fitness_center, size: 30, color: Colors.black),
                        onPressed: () {
                          Navigator.pushNamed(context, '/exercise');
                        }),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    IconButton(
                    icon: const Icon(Icons.people, size: 30, color: Colors.black),
                    onPressed: () {
                      Navigator.pushNamed(context, '/pro');
                    },
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
