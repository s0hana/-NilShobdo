import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              // 🔹 Top Navigation Bar (Blue Container with Icons)
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
                  children:  [
                    IconButton(
                      icon: const Icon(Icons.settings, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/set");
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/note');
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Welcome Message
              const Center(
                child: Column(
                  children: [
                    Text(
                      "Hi, Rahul!\nWelcome Back!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 200),

                    // Box with bordered text
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          color: Colors.white70,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                          child: Text(
                            "chat-history-based\nsupportive messages\n/suggestions",
                            textAlign: TextAlign.center,
                            style: TextStyle(
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

              // 🔹 Bottom Navigation Bar (Blue Container with Icons)
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
                      onTap: ()
                      {
                        Navigator.pushNamed(context, '/chat');
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
                      }
                      
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 30, color: Colors.black),
                      onPressed: ()
                      {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    GestureDetector(
                      onTap: ()
                      {
                        Navigator.pushNamed(context, '/pro');
                      },
                      child: Image.asset(
                      'assets/icons/a.png',
                      height: 30,
                      width: 30,
                      color: Colors.black,
                    ),
                    )
                    
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
